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
import queue
from pathlib import Path
import websockets
from websockets import Headers
import sounddevice as sd
import numpy as np
# 不再需要subprocess和tempfile，因为不用FFmpeg解码
from collections import deque
from typing import Optional
from logger import logger

# PyOgg当前版本不支持流式解码，使用优化的FFmpeg
PYOGG_AVAILABLE = False  # 禁用PyOgg，使用FFmpeg

# 添加路径
current_dir = os.path.dirname(os.path.abspath(__file__))
# AST SDK路径 - 现在backend在s2s下，ast_python在s2s根目录
ast_dir = os.path.join(os.path.dirname(current_dir), "ast_python")
protogen_dir = os.path.join(ast_dir, "python_protogen")
sys.path.append(ast_dir)
sys.path.append(protogen_dir)

from python_protogen.products.understanding.ast.ast_service_pb2 import TranslateRequest, TranslateResponse
from python_protogen.common.events_pb2 import Type

# 使用优化的PCM直通（无需解码）

class SimplePCMPlayer:
    """极简PCM播放器：纯FIFO播放无处理"""
    
    def __init__(self, rate: int = 48000, channels: int = 1, device: Optional[int] = None):
        self.rate = rate
        self.channels = channels
        self.device = device
        self.buffer = deque()
        self.buf_lock = threading.Lock()
        self.stream: Optional[sd.OutputStream] = None
        self.running = False
        self.last_sample = 0.0  # 仅用于防止爆音
        self.max_buffer_size = 50  # 最多缓存50个音频块，优化内存使用
        self.total_samples = 0  # 统计总样本数，用于监控
        
    def _callback(self, outdata, frames, time_info, status):
        """回调：带淡出效果的音频播放"""
        
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
        
        # 将音频发送到声卡
        outdata[:] = out.reshape(frames, self.channels)
    
    def start(self):
        if self.running:
            return
        self.stream = sd.OutputStream(
            samplerate=self.rate,
            channels=self.channels,
            dtype='float32',
            callback=self._callback,
            blocksize=int(self.rate * 0.01),  # 10ms (WebRTC标准)
            device=self.device
        )
        self.stream.start()
        self.running = True
        logger.info("播放流已启动")
    
    def stop(self):
        if self.stream:
            self.stream.stop()
            self.stream.close()
        self.running = False
        with self.buf_lock:
            self.buffer.clear()
        logger.info("播放流已停止")
    
    def enqueue_float32(self, pcm: np.ndarray):
        """添加音频到播放队列"""
        if pcm.ndim != 1:
            pcm = pcm.reshape(-1)
        
        pcm = pcm.astype(np.float32)
        
        # 注意：参考帧现在由播放回调统一添加，避免重复
        # TTS音频会在播放时自动作为参考信号
        
        # 仅在句子末端应用极短淡出（2ms）防止爆音
        if pcm.size > 96:  # 确保有足够样本
            fade_samples = min(96, pcm.size // 20)  # 最多2ms @48kHz
            
            # 使用余弦曲线实现平滑淡出（比线性更自然）
            t = np.linspace(0, np.pi/2, fade_samples)
            fade_curve = np.cos(t)  # 从1平滑降到0
            
            # 仅处理最后几个样本，保持音频主体不变
            pcm[-fade_samples:] = pcm[-fade_samples:] * fade_curve
        
        with self.buf_lock:
            # 防止缓冲区无限增长
            if len(self.buffer) >= self.max_buffer_size:
                dropped = self.buffer.popleft()  # 丢弃最旧的音频块
                logger.warning(f"Audio buffer full, dropping {len(dropped)} samples")
            self.buffer.append(pcm)
            self.total_samples += len(pcm)

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
    
    def __init__(self, input_device: Optional[int] = None, output_device: Optional[int] = None,
                 source_language: str = 'zh', target_language: str = 'en',
                 on_source_sentence=None, on_translation_sentence=None):
        # 音频参数
        self.sample_rate = 16000
        self.channels = 1
        self.chunk_duration = 0.08  # 80ms
        self.chunk_size = int(self.sample_rate * self.chunk_duration)
        
        # 播放器
        # 设备参数：使用传入值，None表示使用系统默认
        self.input_device = input_device  # None表示系统默认
        self.output_device = output_device  # None表示系统默认
        
        # 语言参数：优先使用传入值
        self.source_language = source_language if source_language else 'zh'
        self.target_language = target_language if target_language else 'en'
        
        logger.info(f"初始化音频设备 - 输入: {self.input_device}, 输出: {self.output_device}")
        
        # 初始化播放器
        self.player = SimplePCMPlayer(rate=48000, channels=1, device=self.output_device)
        
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
        
        # 资源管理
        self.max_queue_size = 300  # 发送队列最大大小（优化内存）
        self.active_tasks = set()  # 跟踪活动的异步任务
        self.session_lock = None  # asyncio.Lock将在run中创建
        
        # 文本缓存（用于完整句子显示）
        self.source_text_buffer = []  # 原文缓存
        self.translation_text_buffer = []  # 译文缓存
        
        # 使用PCM格式，无需解码器
        self._running = True
        self.on_source_sentence = on_source_sentence
        self.on_translation_sentence = on_translation_sentence
        self._watchdog_task_ref = None
        
        
        # 麦克风预缓冲，等待会话就绪后回放，避免开头丢音
        self._mic_prebuffer = deque(maxlen=30)  # 30块*80ms≈2.4s上限（优化内存）
        
    def start_microphone(self):
        """启动麦克风 - 极简版本，无VAD"""
        # 显示实际使用的设备
        import sounddevice as sd
        devices = sd.query_devices()
        
        # 获取输入设备信息
        if self.input_device is None:
            actual_device = sd.default.device[0]
            device_name = "系统默认"
            if actual_device is not None and actual_device < len(devices):
                device_name = f"系统默认 -> {devices[actual_device]['name']}"
        else:
            if self.input_device < len(devices):
                device_name = devices[self.input_device]['name']
                actual_device = self.input_device
            else:
                device_name = f"设备索引 {self.input_device}"
                actual_device = self.input_device
        
        # 获取输出设备信息（用于诊断）
        if self.output_device is None:
            output_device = sd.default.device[1]
            output_name = "系统默认"
            if output_device is not None and output_device < len(devices):
                output_name = f"系统默认 -> {devices[output_device]['name']}"
        else:
            if self.output_device < len(devices):
                output_name = devices[self.output_device]['name']
            else:
                output_name = f"设备索引 {self.output_device}"
        
        logger.info(f"音频设备配置:")
        logger.info(f"  输入设备: [{self.input_device}] {device_name}")
        logger.info(f"  输出设备: [{self.output_device}] {output_name}")
        
        # 检查是否是会议模式
        if 'BlackHole' in output_name:
            logger.info("  模式: 会议模式 (输出到BlackHole虚拟音频设备)")
            logger.info("  提醒: 请确保会议软件的麦克风设置为BlackHole，扬声器设置为系统默认")
        
        # 音频块计数器（用于诊断）
        audio_chunk_counter = [0]
        
        def audio_callback(indata, frames, time_info, status):
            """极简回调：只要有会话就发送"""
            if status:
                logger.warning(f"音频状态: {status}")
            
            # 获取原始音频
            audio = indata[:, 0].copy()
            
            # 音频电平监测（每50块打印一次）
            audio_chunk_counter[0] += 1
            if audio_chunk_counter[0] % 50 == 0:  # 每50*80ms=4秒
                audio_level = np.abs(audio).mean()
                if audio_level > 0.001:
                    logger.info(f"[音频输入] 块{audio_chunk_counter[0]}, 电平: {audio_level:.6f} (有声音)")
                else:
                    logger.info(f"[音频输入] 块{audio_chunk_counter[0]}, 电平: {audio_level:.6f} (静音)")
            
            # 转换为16位PCM
            audio_chunk = (audio * 32767).astype(np.int16)
            
            # 如果没有活动会话，启动一个
            if not self.session_active:
                asyncio.run_coroutine_threadsafe(self._start_session(), self.loop)

            data_bytes = audio_chunk.tobytes()
            # 会话未就绪则预缓冲，避免开头丢音
            if not (self.session_active and self.send_queue is not None):
                try:
                    self._mic_prebuffer.append(data_bytes)
                except Exception:
                    pass
                return

            # 先回放预缓冲
            try:
                while self._mic_prebuffer:
                    b = self._mic_prebuffer.popleft()
                    asyncio.run_coroutine_threadsafe(self.send_queue.put(b), self.loop)
            except Exception:
                pass
            
            # 发送当前音频
            try:
                asyncio.run_coroutine_threadsafe(self.send_queue.put(data_bytes), self.loop)
            except Exception as e:
                logger.warning(f"发送失败: {e}")
        
        # 创建输入流
        self.stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=self.channels,
            callback=audio_callback,
            blocksize=self.chunk_size,
            dtype='float32',
            device=self.input_device
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
        # 使用锁防止并发启动会话
        if self.session_lock:
            async with self.session_lock:
                if self.session_active:
                    return
                self.session_active = True
        else:
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
            logger.info(f"WS连接成功 (logid={logid}) [会话{session_num}]")
            
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
            try:
                # 明确请求单声道，避免返回立体声导致通道错配
                start_request.target_audio.channel = 1
            except Exception:
                pass
            
            start_request.request.mode = "s2s"
            start_request.request.source_language = self.source_language
            start_request.request.target_language = self.target_language
            
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
            
            logger.info(f"[会话{session_num}] 启动成功，开始持续发送...")
            
            # 重置重连计数器（成功连接后）
            self.reconnect_attempts = 0
            
            # 启动发送、接收和心跳任务
            self.send_queue = asyncio.Queue(maxsize=self.max_queue_size)  # 限制队列大小
            
            # 跟踪所有任务，便于清理
            sender_task = asyncio.create_task(self._sender_task(session_num))
            receiver_task = asyncio.create_task(self._receiver_task(session_num))
            heartbeat_task = asyncio.create_task(self._heartbeat_task(session_num))
            
            self.active_tasks.update({sender_task, receiver_task, heartbeat_task})
            
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
                        ping_start = time.time()
                        await asyncio.wait_for(pong_waiter, timeout=10)
                        ping_ms = (time.time() - ping_start) * 1000
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
                except asyncio.QueueFull:
                    # 队列满，跳过这个音频块
                    logger.warning("Send queue full, skipping audio chunk")
                    continue
                
                if item is None:
                    continue
                
                # 发送音频块
                chunk_request = TranslateRequest()
                chunk_request.event = Type.TaskRequest
                chunk_request.request_meta.SessionID = self.session_id
                chunk_request.source_audio.binary_data = item
                await self.ws_conn.send(chunk_request.SerializeToString())
                
                chunk_count += 1
                
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
                    # 永不结束会话，只记录日志
                    continue
                
                # 处理会话结束
                if resp.event in (Type.SessionFailed, Type.SessionCanceled):
                    error_msg = resp.response_meta.Message
                    logger.error(f"[会话{session_num}] 失败: {error_msg}")
                    
                    # 检查是否是AudioSendSlow错误，如果是则自动重连
                    if "AudioSendSlow" in error_msg or "audio not enough" in error_msg:
                        logger.warning(f"[会话{session_num}] 检测到音频发送过慢，准备重连...")
                        self.session_active = False
                        # 清理队列
                        if self.send_queue:
                            while not self.send_queue.empty():
                                try:
                                    self.send_queue.get_nowait()
                                except:
                                    break
                        # 指数退避重连
                        self.reconnect_attempts += 1
                        if self.reconnect_attempts <= 10:  # 最多重连10次
                            delay = min(self.reconnect_delay * (2 ** self.reconnect_attempts), self.max_reconnect_delay)
                            logger.warning(f"[会话{session_num}] 将在{delay}秒后重连（第{self.reconnect_attempts}次尝试）")
                            await asyncio.sleep(delay)
                            # 通过看门狗重启，避免重复
                            self.session_active = False
                        else:
                            logger.error(f"[会话{session_num}] 重连次数超过限制，停止重连")
                    break
                    
                if resp.event == Type.SessionFinished:
                    logger.info(f"[会话{session_num}] 结束，共{sentence_count}个句子")
                    break
                
                # 处理TTS句子
                if resp.event == Type.TTSSentenceStart:
                    current_seq = resp.response_meta.Sequence
                    current_data = bytearray()
                    
                elif resp.event == Type.TTSResponse:
                    if current_seq is not None and resp.data:
                        current_data.extend(resp.data)
                
                elif resp.event == Type.TTSSentenceEnd:
                    if current_seq is not None and current_data:
                        # 直接处理PCM数据，无需解码
                        pcm_bytes = bytes(current_data)
                        
                        # 直接转换PCM，无需解码
                        pcm = pcm_to_float32(pcm_bytes)
                        if pcm.size > 0:
                            # 播放高质量PCM音频（参考在播放回调中注入，以保证时序一致）
                            try:
                                self.player.enqueue_float32(pcm)
                            except Exception:
                                pass
                            
                            sentence_count += 1
                        
                        current_seq = None
                        current_data = bytearray()
                
                # 缓存原文和译文，等到句子结束再显示
                elif resp.event == Type.SourceSubtitleStart:
                    # 清空原文缓存，准备新句子
                    self.source_text_buffer = []
                    
                elif resp.event == Type.SourceSubtitleResponse:
                    if resp.text and resp.text.strip():
                        # 缓存原文碎片
                        self.source_text_buffer.append(resp.text.strip())
                        
                elif resp.event == Type.SourceSubtitleEnd:
                    # 原文结束，显示完整句子
                    if self.source_text_buffer:
                        complete_source = ''.join(self.source_text_buffer)
                        logger.info(f"[原文] {complete_source}")
                        if callable(self.on_source_sentence):
                            try:
                                self.on_source_sentence(complete_source)
                            except Exception:
                                pass
                        self.source_text_buffer = []
                        
                elif resp.event == Type.TranslationSubtitleStart:
                    # 清空译文缓存，准备新译文
                    self.translation_text_buffer = []
                    
                elif resp.event == Type.TranslationSubtitleResponse:
                    if resp.text and resp.text.strip():
                        # 缓存译文碎片
                        self.translation_text_buffer.append(resp.text.strip())
                        
                elif resp.event == Type.TranslationSubtitleEnd:
                    # 译文结束，显示完整译文
                    if self.translation_text_buffer:
                        complete_translation = ' '.join(self.translation_text_buffer)  # 译文用空格分隔
                        logger.info(f"[翻译] {complete_translation}")
                        if callable(self.on_translation_sentence):
                            try:
                                self.on_translation_sentence(complete_translation)
                            except Exception:
                                pass
                        self.translation_text_buffer = []
                        
        except Exception as e:
            logger.error(f"接收任务异常: {e}")
            
        finally:
            # 清理所有资源
            logger.info(f"[会话{session_num}] 清理资源...")
            
            # 关闭WebSocket连接
            if self.ws_conn:
                try:
                    await self.ws_conn.close()
                except Exception:
                    pass
            
            # 取消所有活动任务
            for task in list(self.active_tasks):
                if not task.done():
                    task.cancel()
            self.active_tasks.clear()
            
            # 清空队列
            if self.send_queue:
                while not self.send_queue.empty():
                    try:
                        self.send_queue.get_nowait()
                    except:
                        break
            
            # 重置状态
            self.ws_conn = None
            self.session_active = False
            self.session_id = None
            self.send_queue = None
    
    async def run(self):
        """运行主循环"""
        self.loop = asyncio.get_event_loop()
        self.session_lock = asyncio.Lock()  # 创建异步锁
        
        
        # 提前建立会话，避免开头语音丢失
        try:
            await self._start_session()
        except Exception as e:
            logger.warning(f"预启动会话失败，将由看门狗重试: {e}")
        
        # 启动音频组件（使用简单的分离流）
        self.player.start()
        self.start_microphone()
        # 启动看门狗
        self._watchdog_task_ref = asyncio.create_task(self._watchdog_task())
        self.active_tasks.add(self._watchdog_task_ref)
        
        
        logger.info("=" * 50)
        logger.info("极简实时翻译系统已启动")
        logger.info("永久会话模式：会话将持续运行，永不结束")
        logger.info("按 Ctrl+C 退出")
        logger.info("=" * 50)
        
        try:
            while self._running:
                await asyncio.sleep(1)
                
        except (KeyboardInterrupt, asyncio.CancelledError):
            logger.info("收到退出信号")
            
        finally:
            try:
                self.stop_microphone()
                self.player.stop()
            except Exception:
                pass
            
            try:
                if self._watchdog_task_ref:
                    self._watchdog_task_ref.cancel()
            except Exception:
                pass

    def stop(self):
        """请求停止运行（线程安全）"""
        logger.info("Stopping translator...")
        self._running = False
        # 取消所有活动任务
        if self.loop and self.active_tasks:
            for task in list(self.active_tasks):
                asyncio.run_coroutine_threadsafe(
                    self._cancel_task(task), self.loop
                )
        
        # 关闭WebSocket连接
        try:
            if self.ws_conn and self.loop:
                asyncio.run_coroutine_threadsafe(self.ws_conn.close(), self.loop)
        except Exception:
            pass
        
        # 清空发送队列，避免阻塞
        try:
            if self.send_queue:
                while not self.send_queue.empty():
                    self.send_queue.get_nowait()
        except Exception:
            pass
        
        # 清理音频播放器缓冲区
        if self.player:
            with self.player.buf_lock:
                self.player.buffer.clear()
        
        logger.info("Translator stop requested")
    
    async def _cancel_task(self, task):
        """安全取消任务"""
        if not task.done():
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

    async def _watchdog_task(self):
        """监视会话与任务状态，异常时自动恢复。"""
        import random
        backoff = 1
        consecutive_failures = 0
        max_consecutive_failures = 5
        
        while self._running:
            try:
                if not self.session_active:
                    # 等待一段时间，避免频繁重连
                    await asyncio.sleep(backoff)
                    
                    # 检查连续失败次数
                    if consecutive_failures >= max_consecutive_failures:
                        logger.error(f"连续{consecutive_failures}次重连失败，看门狗暂停60秒")
                        await asyncio.sleep(60)
                        consecutive_failures = 0
                        backoff = 1
                        continue
                    
                    # 尝试重建会话
                    try:
                        logger.info(f"看门狗：尝试重建会话 (backoff={backoff}s)")
                        await self._start_session()
                        # 成功后重置计数器
                        backoff = 1
                        consecutive_failures = 0
                    except Exception as e:
                        consecutive_failures += 1
                        logger.warning(f"看门狗重连失败 ({consecutive_failures}/{max_consecutive_failures}): {e}")
                        # 指数退避，最多16秒
                        backoff = min(backoff * 2, 16)
                else:
                    # 会话活跃，检查任务健康状态
                    await asyncio.sleep(5)
                    # 清理已完成的任务
                    self.active_tasks = {task for task in self.active_tasks if not task.done()}
                    
            except asyncio.CancelledError:
                logger.info("看门狗任务被取消")
                break
            except Exception as e:
                logger.error(f"看门狗异常: {e}")
                await asyncio.sleep(random.uniform(2.0, 5.0))
    

async def main():
    """主函数"""
    translator = SimpleRealtimeTranslator()
    try:
        await translator.run()
    except (KeyboardInterrupt, asyncio.CancelledError):
        logger.info("程序正在退出...")
        translator.stop()

if __name__ == "__main__":
    # 列出音频输入设备
    logger.info("可用的音频输入设备:")
    devices = sd.query_devices()
    for i, device in enumerate(devices):
        if device['max_input_channels'] > 0:
            marker = " (默认)" if i == sd.default.device[0] else ""
            logger.info(f"  [{i}] {device['name']}{marker}")
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("程序已退出")

