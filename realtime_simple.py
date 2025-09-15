#!/usr/bin/env python3
"""
极简实时麦克风翻译系统
核心原则：完全信任API能力，最小化客户端干预
"""
import asyncio
import uuid
import os
import sys
import time
import logging
import threading
from pathlib import Path
import websockets
from websockets import Headers
import sounddevice as sd
import numpy as np
# 不再需要subprocess和tempfile，因为不用FFmpeg解码
from collections import deque
from typing import Optional

# PyOgg当前版本不支持流式解码，使用优化的FFmpeg
PYOGG_AVAILABLE = False  # 禁用PyOgg，使用FFmpeg

# 添加路径
current_dir = os.path.dirname(os.path.abspath(__file__))
protogen_dir = os.path.join(current_dir, "ast_python", "python_protogen")
sys.path.append(os.path.join(current_dir, "ast_python"))
sys.path.append(protogen_dir)

from python_protogen.products.understanding.ast.ast_service_pb2 import TranslateRequest, TranslateResponse
from python_protogen.common.events_pb2 import Type

logging.basicConfig(level=logging.WARNING, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# 使用优化的FFmpeg解码
logger.info("使用优化的FFmpeg解码器")

class SimplePCMPlayer:
    """极简PCM播放器：纯FIFO播放无处理"""
    
    def __init__(self, rate: int = 48000, channels: int = 1):
        self.rate = rate
        self.channels = channels
        self.buffer = deque()
        self.buf_lock = threading.Lock()
        self.stream: Optional[sd.OutputStream] = None
        self.running = False
        self.last_sample = 0.0  # 仅用于防止爆音
        
    def _callback(self, outdata, frames, time_info, status):
        """回调：带淡出效果的音频播放"""
        if status:
            logger.debug(f"输出状态: {status}")
        
        samples_needed = frames * self.channels
        out = np.zeros(samples_needed, dtype=np.float32)
        filled = 0
        
        with self.buf_lock:
            while self.buffer and filled < samples_needed:
                chunk = self.buffer[0]
                take = min(len(chunk), samples_needed - filled)
                if take > 0:
                    out[filled:filled+take] = chunk[:take]
                    self.last_sample = chunk[take-1] if take > 0 else self.last_sample
                if take < len(chunk):
                    self.buffer[0] = chunk[take:]
                else:
                    self.buffer.popleft()
                filled += take
        
        # 如果没有足够的音频数据，仅做最小化平滑避免爆音
        if filled < samples_needed and filled > 0:
            # 只在有部分数据时才平滑，完全空时保持静音
            fade_samples = min(16, samples_needed - filled)  # 极短淡出（约0.3ms）
            if self.last_sample != 0:
                fade_curve = np.linspace(self.last_sample * 0.5, 0, fade_samples)
                out[filled:filled+fade_samples] = fade_curve
            self.last_sample = 0.0
        elif filled == 0:
            # 缓冲区完全空，保持静音
            self.last_sample = 0.0
        
        outdata[:] = out.reshape(frames, self.channels)
    
    def start(self):
        if self.running:
            return
        self.stream = sd.OutputStream(
            samplerate=self.rate,
            channels=self.channels,
            dtype='float32',
            callback=self._callback,
            blocksize=int(self.rate * 0.02)  # 20ms
        )
        self.stream.start()
        self.running = True
        print("播放流已启动")
    
    def stop(self):
        if self.stream:
            self.stream.stop()
            self.stream.close()
        self.running = False
        with self.buf_lock:
            self.buffer.clear()
        logger.info("播放流已停止")
    
    def enqueue_float32(self, pcm: np.ndarray):
        """添加音频到播放队列 - 仅句末微淡出防爆音"""
        if pcm.ndim != 1:
            pcm = pcm.reshape(-1)
        
        pcm = pcm.astype(np.float32)
        
        # 仅在句子末端应用极短淡出（2ms）防止爆音
        # 不会引入电音，因为处理范围极小且使用平滑曲线
        if pcm.size > 96:  # 确保有足够样本
            fade_samples = min(96, pcm.size // 20)  # 最多2ms @48kHz
            
            # 使用余弦曲线实现平滑淡出（比线性更自然）
            t = np.linspace(0, np.pi/2, fade_samples)
            fade_curve = np.cos(t)  # 从1平滑降到0
            
            # 仅处理最后几个样本，保持音频主体不变
            pcm[-fade_samples:] = pcm[-fade_samples:] * fade_curve
        
        with self.buf_lock:
            self.buffer.append(pcm)

def pcm_to_float32(pcm_bytes: bytes) -> np.ndarray:
    """直接转换PCM到float32 - 无需解码，避免artifacts"""
    try:
        # PCM格式直接转换，无需FFmpeg
        pcm_s16 = np.frombuffer(pcm_bytes, dtype=np.int16)
        if pcm_s16.size == 0:
            return np.zeros(0, dtype=np.float32)
        return pcm_s16.astype(np.float32) / 32768.0
    except Exception as e:
        logger.error(f"PCM转换异常: {e}")
        return np.zeros(0, dtype=np.float32)

class SimpleRealtimeTranslator:
    """极简实时翻译器"""
    
    def __init__(self):
        # 音频参数
        self.sample_rate = 16000
        self.channels = 1
        self.chunk_duration = 0.08  # 80ms
        self.chunk_size = int(self.sample_rate * self.chunk_duration)
        
        # 播放器
        self.player = SimplePCMPlayer(rate=48000, channels=1)
        
        # 会话管理
        self.send_queue: Optional[asyncio.Queue] = None
        self.ws_conn = None
        self.session_active = False
        self.session_id = None
        self.session_count = 0
        # 永不结束会话，保持持续连接
        
        # 重连策略
        self.reconnect_delay = 1  # 初始重连延迟（秒）
        self.max_reconnect_delay = 32  # 最大重连延迟（秒）
        self.reconnect_attempts = 0
        
        # 文本缓存（用于完整句子显示）
        self.source_text_buffer = []  # 原文缓存
        self.translation_text_buffer = []  # 译文缓存
        
        # 使用PCM格式，无需解码器
        
    def start_microphone(self):
        """启动麦克风 - 极简版本，无VAD"""
        print("启动麦克风（无VAD，持续发送）...")
        
        def audio_callback(indata, frames, time_info, status):
            """极简回调：只要有会话就发送"""
            if status:
                logger.warning(f"音频状态: {status}")
            
            # 转换为16位PCM
            audio_chunk = (indata[:, 0] * 32767).astype(np.int16)
            
            # 如果没有活动会话，启动一个
            if not self.session_active:
                print("🎤 启动永久会话...")
                asyncio.run_coroutine_threadsafe(self._start_session(), self.loop)
            
            # 持续发送音频
            if self.session_active and self.send_queue is not None:
                try:
                    asyncio.run_coroutine_threadsafe(
                        self.send_queue.put(audio_chunk.tobytes()),
                        self.loop
                    )
                except Exception as e:
                    logger.warning(f"发送失败: {e}")
        
        # 创建输入流
        self.stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=self.channels,
            callback=audio_callback,
            blocksize=self.chunk_size,
            dtype='float32'
        )
        self.stream.start()
        logger.info("麦克风已启动，持续监听...")
    
    def stop_microphone(self):
        """停止麦克风"""
        if hasattr(self, 'stream'):
            self.stream.stop()
            self.stream.close()
        logger.info("麦克风已停止")
    
    async def _start_session(self):
        """建立会话并保持长时间运行"""
        if self.session_active:
            logger.debug("会话已活动")
            return
        
        self.session_active = True
        
        try:
            from config import Config
            config = Config.from_env()
            self.session_count += 1
            session_num = self.session_count
            
            conn_id = str(uuid.uuid4())
            headers = Headers({
                "X-Api-App-Key": config.api.app_key,
                "X-Api-Access-Key": config.api.access_key,
                "X-Api-Resource-Id": config.api.resource_id,
                "X-Api-Connect-Id": conn_id
            })
            
            os.environ['NO_PROXY'] = '*'
            
            # 初始连接重试机制
            connect_attempts = 0
            max_connect_attempts = 3
            while connect_attempts < max_connect_attempts:
                try:
                    self.ws_conn = await asyncio.wait_for(
                        websockets.connect(
                            config.api.ws_url,
                            additional_headers=headers,
                            max_size=1000000000,
                            ping_interval=None,
                            open_timeout=20  # 增加超时时间
                        ),
                        timeout=20  # 总超时时20秒
                    )
                    break  # 成功连接，退出重试循环
                except (asyncio.TimeoutError, Exception) as e:
                    connect_attempts += 1
                    if connect_attempts >= max_connect_attempts:
                        raise e
                    retry_delay = min(2 ** connect_attempts, 8)  # 指数退避：2s, 4s, 8s
                    logger.warning(f"连接失败（第{connect_attempts}次），{retry_delay}秒后重试: {e}")
                    await asyncio.sleep(retry_delay)
            
            logid = getattr(self.ws_conn.response, 'headers', {}).get('X-Tt-Logid', None)
            print(f"WS连接成功 (logid={logid}) [会话{session_num}]")
            
            self.session_id = str(uuid.uuid4())
            start_request = TranslateRequest()
            start_request.event = Type.StartSession
            start_request.request_meta.SessionID = self.session_id
            start_request.user.uid = "simple_realtime"
            start_request.user.did = "simple_realtime"
            
            # 源音频配置
            start_request.source_audio.format = "wav"
            start_request.source_audio.rate = 16000
            start_request.source_audio.bits = 16
            start_request.source_audio.channel = 1
            
            # 目标音频配置 - 使用PCM格式避免解码artifacts
            start_request.target_audio.format = "pcm"  # PCM格式，无需解码
            start_request.target_audio.rate = 48000  # 48kHz高音质
            
            start_request.request.mode = "s2s"
            start_request.request.source_language = "zh"
            start_request.request.target_language = "en"
            
            # 启用降噪功能
            start_request.denoise = True
            
            await self.ws_conn.send(start_request.SerializeToString())
            
            # 等待SessionStarted
            resp_data = await self.ws_conn.recv()
            resp = TranslateResponse()
            resp.ParseFromString(resp_data)
            
            if resp.event != Type.SessionStarted:
                logger.error(f"会话启动失败: {resp.event}")
                await self.ws_conn.close()
                self.ws_conn = None
                self.session_active = False
                return
            
            print(f"[会话{session_num}] 启动成功，开始持续发送...")
            
            # 重置重连计数器（成功连接后）
            self.reconnect_attempts = 0
            
            # 启动发送、接收和心跳任务
            self.send_queue = asyncio.Queue()
            asyncio.create_task(self._sender_task(session_num))
            asyncio.create_task(self._receiver_task(session_num))
            asyncio.create_task(self._heartbeat_task(session_num))
            
        except Exception as e:
            logger.error(f"建立会话失败: {e}")
            self.session_active = False
            if self.ws_conn:
                try:
                    await self.ws_conn.close()
                except:
                    pass
            self.ws_conn = None
    
    async def _heartbeat_task(self, session_num: int):
        """心跳任务：定期发送ping保持连接活跃"""
        try:
            while self.session_active:
                await asyncio.sleep(30)  # 每30秒发送一次心跳
                if self.ws_conn:
                    try:
                        # 发送WebSocket ping
                        pong_waiter = await self.ws_conn.ping()
                        await asyncio.wait_for(pong_waiter, timeout=10)
                        logger.debug(f"[会话{session_num}] 心跳成功")
                    except asyncio.TimeoutError:
                        logger.warning(f"[会话{session_num}] 心跳超时，可能网络不稳定")
                    except websockets.exceptions.ConnectionClosed:
                        logger.warning(f"[会话{session_num}] 连接已关闭，停止心跳")
                        break
                    except Exception as e:
                        logger.warning(f"[会话{session_num}] 心跳失败: {e}")
        except Exception as e:
            logger.error(f"心跳任务异常: {e}")
    
    async def _sender_task(self, session_num: int):
        """发送任务：基于时间戳的精确80ms发送"""
        try:
            chunk_count = 0
            next_send_time = time.time()
            
            while self.session_active:
                try:
                    # 使用非阻塞get避免延迟
                    item = await asyncio.wait_for(self.send_queue.get(), timeout=0.01)
                except asyncio.TimeoutError:
                    # 队列为空，发送静音保持时间同步
                    item = np.zeros(int(self.sample_rate * 0.08), dtype=np.int16).tobytes()
                
                if item is None:
                    continue
                
                # 发送音频块
                chunk_request = TranslateRequest()
                chunk_request.event = Type.TaskRequest
                chunk_request.request_meta.SessionID = self.session_id
                chunk_request.source_audio.binary_data = item
                await self.ws_conn.send(chunk_request.SerializeToString())
                
                chunk_count += 1
                if chunk_count % 200 == 0:
                    logger.debug(f"[会话{session_num}] 已发送{chunk_count}块")
                
                # 基于时间戳的精确间隔，避免累积延迟
                next_send_time += 0.08
                wait_time = next_send_time - time.time()
                if wait_time > 0:
                    await asyncio.sleep(wait_time)
                elif wait_time < -0.5:
                    # 延迟太大，重置时间基准
                    logger.warning(f"[会话{session_num}] 重置时间基准（延迟{-wait_time:.2f}秒）")
                    next_send_time = time.time()
                    
        except Exception as e:
            logger.error(f"发送任务异常: {e}")
            self.session_active = False
    
    async def _receiver_task(self, session_num: int):
        """接收任务：极简处理，直接播放"""
        current_seq = None
        current_data = bytearray()
        sentence_count = 0
        
        try:
            while True:
                resp_data = await self.ws_conn.recv()
                resp = TranslateResponse()
                resp.ParseFromString(resp_data)
                
                # 处理AudioMuted事件
                if resp.event == Type.AudioMuted:
                    muted_duration = resp.muted_duration_ms
                    logger.debug(f"[会话{session_num}] 静音{muted_duration}ms，保持会话")
                    # 永不结束会话，只记录日志
                    continue
                
                # 处理会话结束
                if resp.event in (Type.SessionFailed, Type.SessionCanceled):
                    error_msg = resp.response_meta.Message
                    logger.error(f"[会话{session_num}] 失败: {error_msg}")
                    
                    # 检查是否是AudioSendSlow错误，如果是则自动重连
                    if "AudioSendSlow" in error_msg or "audio not enough" in error_msg:
                        print(f"[会话{session_num}] 检测到音频发送过慢，准备重连...")
                        self.session_active = False
                        # 清理队列
                        while not self.send_queue.empty():
                            try:
                                self.send_queue.get_nowait()
                            except:
                                pass
                        # 指数退避重连
                        self.reconnect_attempts += 1
                        delay = min(self.reconnect_delay * (2 ** self.reconnect_attempts), self.max_reconnect_delay)
                        print(f"[会话{session_num}] 将在{delay}秒后重连（第{self.reconnect_attempts}次尝试）")
                        await asyncio.sleep(delay)
                        asyncio.create_task(self._start_session())
                    break
                    
                if resp.event == Type.SessionFinished:
                    logger.info(f"[会话{session_num}] 结束，共{sentence_count}个句子")
                    break
                
                # 处理TTS句子
                if resp.event == Type.TTSSentenceStart:
                    current_seq = resp.response_meta.Sequence
                    current_data = bytearray()
                    logger.debug(f"[会话{session_num}] 句子{current_seq}开始")
                    
                elif resp.event == Type.TTSResponse:
                    if current_seq is not None and resp.data:
                        current_data.extend(resp.data)
                        
                elif resp.event == Type.TTSSentenceEnd:
                    if current_seq is not None and current_data:
                        # 直接处理PCM数据，无需解码
                        pcm_bytes = bytes(current_data)
                        
                        # 调试信息
                        logger.debug(f"[会话{session_num}] 句子{current_seq}: PCM数据, {len(current_data)} bytes")
                        
                        # 直接转换PCM，无需解码，避免所有artifacts
                        pcm = pcm_to_float32(pcm_bytes)
                        if pcm.size > 0:
                            # 播放高质量PCM音频
                            self.player.enqueue_float32(pcm)
                            
                            sentence_count += 1
                            if sentence_count % 10 == 0:
                                print(f"[会话{session_num}] 已处理{sentence_count}个句子")
                        
                        current_seq = None
                        current_data = bytearray()
                
                # 缓存原文和译文，等到句子结束再显示
                elif resp.event == Type.SourceSubtitleStart:
                    # 清空原文缓存，准备新句子
                    self.source_text_buffer = []
                    logger.debug(f"[会话{session_num}] 原文开始")
                    
                elif resp.event == Type.SourceSubtitleResponse:
                    if resp.text and resp.text.strip():
                        # 缓存原文碎片
                        self.source_text_buffer.append(resp.text.strip())
                        
                elif resp.event == Type.SourceSubtitleEnd:
                    # 原文结束，显示完整句子
                    if self.source_text_buffer:
                        complete_source = ''.join(self.source_text_buffer)
                        print(f"\n[原文] {complete_source}")
                        self.source_text_buffer = []
                        
                elif resp.event == Type.TranslationSubtitleStart:
                    # 清空译文缓存，准备新译文
                    self.translation_text_buffer = []
                    logger.debug(f"[会话{session_num}] 译文开始")
                    
                elif resp.event == Type.TranslationSubtitleResponse:
                    if resp.text and resp.text.strip():
                        # 缓存译文碎片
                        self.translation_text_buffer.append(resp.text.strip())
                        
                elif resp.event == Type.TranslationSubtitleEnd:
                    # 译文结束，显示完整译文
                    if self.translation_text_buffer:
                        complete_translation = ' '.join(self.translation_text_buffer)  # 译文用空格分隔
                        print(f"[翻译] {complete_translation}")
                        self.translation_text_buffer = []
                        
        except Exception as e:
            logger.error(f"接收任务异常: {e}")
            
        finally:
            # 清理
            try:
                await self.ws_conn.close()
            except:
                pass
            self.ws_conn = None
            self.session_active = False
            self.session_id = None
    
    async def run(self):
        """运行主循环"""
        self.loop = asyncio.get_event_loop()
        
        # 启动组件
        self.player.start()
        self.start_microphone()
        
        print("=" * 50)
        print("极简实时翻译系统已启动")
        print("永久会话模式：会话将持续运行，永不结束")
        print("按 Ctrl+C 退出")
        print("=" * 50)
        
        try:
            while True:
                await asyncio.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("收到退出信号")
            
        finally:
            self.stop_microphone()
            self.player.stop()

async def main():
    """主函数"""
    translator = SimpleRealtimeTranslator()
    await translator.run()

if __name__ == "__main__":
    # 列出音频设备
    print("可用的音频输入设备:")
    devices = sd.query_devices()
    for i, device in enumerate(devices):
        if device['max_input_channels'] > 0:
            marker = " (默认)" if i == sd.default.device[0] else ""
            print(f"  [{i}] {device['name']}{marker}")
    
    print("")
    asyncio.run(main())