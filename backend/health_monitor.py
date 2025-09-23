#!/usr/bin/env python3
"""
健康监控模块 - 监控应用运行状态和性能指标
"""
import time
import threading
import psutil
from typing import Dict, Any, Optional
from collections import deque
from dataclasses import dataclass, field
from enum import Enum
from logger import logger


class SessionState(Enum):
    """会话状态枚举"""
    IDLE = "idle"  # 空闲
    CONNECTING = "connecting"  # 连接中
    CONNECTED = "connected"  # 已连接
    DISCONNECTING = "disconnecting"  # 断开中
    ERROR = "error"  # 错误状态
    RECONNECTING = "reconnecting"  # 重连中


@dataclass
class HealthMetrics:
    """健康指标"""
    # 内存指标
    memory_usage_mb: float = 0.0
    memory_percent: float = 0.0
    
    # 线程/任务指标
    thread_count: int = 0
    active_tasks: int = 0
    
    # 缓冲区指标
    audio_buffer_size: int = 0
    send_queue_size: int = 0
    
    # 会话指标
    session_state: SessionState = SessionState.IDLE
    reconnect_count: int = 0
    error_count: int = 0
    
    # 性能指标
    audio_latency_ms: float = 0.0
    websocket_ping_ms: float = 0.0
    
    # 统计信息
    total_sentences: int = 0
    total_audio_samples: int = 0
    uptime_seconds: float = 0.0
    
    # 错误历史
    recent_errors: deque = field(default_factory=lambda: deque(maxlen=10))
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'memory_usage_mb': self.memory_usage_mb,
            'memory_percent': self.memory_percent,
            'thread_count': self.thread_count,
            'active_tasks': self.active_tasks,
            'audio_buffer_size': self.audio_buffer_size,
            'send_queue_size': self.send_queue_size,
            'session_state': self.session_state.value,
            'reconnect_count': self.reconnect_count,
            'error_count': self.error_count,
            'audio_latency_ms': self.audio_latency_ms,
            'websocket_ping_ms': self.websocket_ping_ms,
            'total_sentences': self.total_sentences,
            'total_audio_samples': self.total_audio_samples,
            'uptime_seconds': self.uptime_seconds,
            'recent_errors': list(self.recent_errors)
        }


class HealthMonitor:
    """健康监控器"""
    
    def __init__(self):
        self.metrics = HealthMetrics()
        self.start_time = time.time()
        self.lock = threading.Lock()
        self.running = False
        self.monitor_thread: Optional[threading.Thread] = None
        
        # 警告阈值
        self.thresholds = {
            'memory_percent': 80.0,  # 内存使用超过80%警告
            'thread_count': 50,  # 线程数超过50警告
            'audio_buffer_size': 80,  # 音频缓冲区超过80个块警告
            'send_queue_size': 400,  # 发送队列超过400警告
            'error_count': 10,  # 错误数超过10警告
            'reconnect_count': 5,  # 重连次数超过5警告
        }
        
        # 性能历史记录（用于计算平均值）
        self.latency_history = deque(maxlen=100)
        self.ping_history = deque(maxlen=100)
        
    def start(self):
        """启动监控"""
        if self.running:
            return
        
        self.running = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()
        logger.info("健康监控已启动")
        
    def stop(self):
        """停止监控"""
        self.running = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=2)
        logger.info("健康监控已停止")
        
    def _monitor_loop(self):
        """监控循环"""
        while self.running:
            try:
                self._update_system_metrics()
                self._check_thresholds()
                time.sleep(5)  # 每5秒更新一次
            except Exception as e:
                logger.error(f"监控循环异常: {e}")
                time.sleep(10)
                
    def _update_system_metrics(self):
        """更新系统指标"""
        try:
            process = psutil.Process()
            
            with self.lock:
                # 内存使用
                mem_info = process.memory_info()
                self.metrics.memory_usage_mb = mem_info.rss / 1024 / 1024
                self.metrics.memory_percent = process.memory_percent()
                
                # 线程数
                self.metrics.thread_count = process.num_threads()
                
                # 运行时间
                self.metrics.uptime_seconds = time.time() - self.start_time
                
        except Exception as e:
            logger.debug(f"更新系统指标失败: {e}")
            
    def _check_thresholds(self):
        """检查阈值并发出警告"""
        warnings = []
        
        with self.lock:
            if self.metrics.memory_percent > self.thresholds['memory_percent']:
                warnings.append(f"内存使用率过高: {self.metrics.memory_percent:.1f}%")
                
            if self.metrics.thread_count > self.thresholds['thread_count']:
                warnings.append(f"线程数过多: {self.metrics.thread_count}")
                
            if self.metrics.audio_buffer_size > self.thresholds['audio_buffer_size']:
                warnings.append(f"音频缓冲区过大: {self.metrics.audio_buffer_size}")
                
            if self.metrics.send_queue_size > self.thresholds['send_queue_size']:
                warnings.append(f"发送队列过大: {self.metrics.send_queue_size}")
                
            if self.metrics.error_count > self.thresholds['error_count']:
                warnings.append(f"错误次数过多: {self.metrics.error_count}")
                
            if self.metrics.reconnect_count > self.thresholds['reconnect_count']:
                warnings.append(f"重连次数过多: {self.metrics.reconnect_count}")
                
        for warning in warnings:
            logger.warning(f"[健康监控] {warning}")
            
    def update_session_state(self, state: SessionState):
        """更新会话状态"""
        with self.lock:
            self.metrics.session_state = state
            logger.debug(f"会话状态更新: {state.value}")
            
    def update_buffer_size(self, audio_buffer: int, send_queue: int):
        """更新缓冲区大小"""
        with self.lock:
            self.metrics.audio_buffer_size = audio_buffer
            self.metrics.send_queue_size = send_queue
            
    def update_latency(self, audio_ms: Optional[float] = None, ping_ms: Optional[float] = None):
        """更新延迟指标"""
        with self.lock:
            if audio_ms is not None:
                self.latency_history.append(audio_ms)
                self.metrics.audio_latency_ms = sum(self.latency_history) / len(self.latency_history)
                
            if ping_ms is not None:
                self.ping_history.append(ping_ms)
                self.metrics.websocket_ping_ms = sum(self.ping_history) / len(self.ping_history)
                
    def record_error(self, error_msg: str):
        """记录错误"""
        with self.lock:
            self.metrics.error_count += 1
            self.metrics.recent_errors.append({
                'time': time.time(),
                'message': str(error_msg)[:200]  # 限制长度
            })
            
    def record_reconnect(self):
        """记录重连"""
        with self.lock:
            self.metrics.reconnect_count += 1
            
    def record_sentence(self):
        """记录句子数"""
        with self.lock:
            self.metrics.total_sentences += 1
            
    def update_audio_samples(self, count: int):
        """更新音频样本数"""
        with self.lock:
            self.metrics.total_audio_samples = count
            
    def update_active_tasks(self, count: int):
        """更新活动任务数"""
        with self.lock:
            self.metrics.active_tasks = count
            
    def get_metrics(self) -> HealthMetrics:
        """获取当前指标"""
        with self.lock:
            return self.metrics
            
    def get_health_status(self) -> Dict[str, Any]:
        """获取健康状态摘要"""
        with self.lock:
            is_healthy = (
                self.metrics.memory_percent < self.thresholds['memory_percent'] and
                self.metrics.thread_count < self.thresholds['thread_count'] and
                self.metrics.error_count < self.thresholds['error_count'] and
                self.metrics.session_state != SessionState.ERROR
            )
            
            return {
                'healthy': is_healthy,
                'uptime': self.metrics.uptime_seconds,
                'state': self.metrics.session_state.value,
                'metrics': self.metrics.to_dict()
            }
            
    def reset_counters(self):
        """重置计数器（用于重启后）"""
        with self.lock:
            self.metrics.reconnect_count = 0
            self.metrics.error_count = 0
            self.metrics.total_sentences = 0
            self.metrics.recent_errors.clear()
            logger.info("健康监控计数器已重置")


# 全局监控器实例
_monitor_instance: Optional[HealthMonitor] = None


def get_monitor() -> HealthMonitor:
    """获取全局监控器实例"""
    global _monitor_instance
    if _monitor_instance is None:
        _monitor_instance = HealthMonitor()
    return _monitor_instance