"""
配置管理模块
管理API认证、音频参数等配置
"""
from __future__ import annotations
import os
import sys
import json
from dataclasses import dataclass
from typing import Optional, Union
from dotenv import load_dotenv
try:
    import keyring
except Exception:
    keyring = None

load_dotenv()

# 配置缓存，避免重复加载和多次Keychain访问
_config_cache = None

@dataclass
class AudioConfig:
    """音频相关配置"""
    sample_rate: int = 16000
    channels: int = 1
    chunk_ms: int = 80
    bits: int = 16
    format: str = "wav"
    codec: str = "raw"
    # 可选设备（索引或None）
    input_device: Optional[int] = None
    output_device: Optional[int] = None
    
    @property
    def chunk_size(self) -> int:
        """计算每个音频块的样本数"""
        return int(self.sample_rate * self.chunk_ms / 1000)
    
    @property
    def bytes_per_chunk(self) -> int:
        """计算每个音频块的字节数"""
        return self.chunk_size * self.channels * (self.bits // 8)

@dataclass
class TargetAudioConfig:
    """目标音频配置"""
    format: str = "pcm"  # 使用PCM格式避免解码问题
    rate: int = 24000

@dataclass
class APIConfig:
    """API认证配置"""
    app_key: str
    access_key: str
    resource_id: str = "volc.service_type.10053"
    ws_url: str = "wss://openspeech.bytedance.com/api/v4/ast/v2/translate"

@dataclass
class TranslationConfig:
    """翻译配置"""
    mode: str = "s2s"
    source_language: str = "zh"
    target_language: str = "en"

@dataclass
class Config:
    """主配置类"""
    api: APIConfig
    audio: AudioConfig
    target_audio: TargetAudioConfig
    translation: TranslationConfig
    virtual_device_name: Optional[str] = None
    
    @classmethod
    def from_env(cls, use_cache: bool = True) -> 'Config':
        """从环境变量加载配置
        
        Args:
            use_cache: 是否使用缓存的配置（默认True，避免重复Keychain访问）
        """
        global _config_cache
        
        # 如果有缓存且允许使用，直接返回
        if use_cache and _config_cache is not None:
            return _config_cache
        def _get_secret(key: str, default: str = '') -> str:
            # 优先级：env -> app_secrets.json -> keyring
            val = os.getenv(key)
            if val:
                return val
            
            # app_secrets.json 尝试（优先于keyring，避免弹窗）
            # 检查多个可能的位置
            possible_paths = [
                'app_secrets.json',  # 当前目录
                os.path.join(os.path.dirname(__file__), 'app_secrets.json'),  # 脚本同目录
                os.path.join(getattr(sys, '_MEIPASS', '.'), 'app_secrets.json') if hasattr(sys, '_MEIPASS') else None,  # PyInstaller bundle
                # macOS app bundle Resources
                os.path.join(os.path.dirname(os.path.dirname(getattr(sys, '_MEIPASS', '.'))), 'Resources', 'app_secrets.json') if hasattr(sys, '_MEIPASS') else None,
            ]
            for path in possible_paths:
                if path and os.path.exists(path):
                    try:
                        with open(path, 'r') as f:
                            data = json.load(f)
                            if key in data and data[key]:
                                return data[key]
                    except Exception:
                        pass
            
            # keyring 尝试（最后尝试，避免不必要的弹窗）
            if keyring:
                try:
                    v = keyring.get_password('BabelAI', key)
                    if v:
                        return v
                except Exception:
                    pass
            
            return default

        # 读取顺序：env -> app_secrets.json -> keychain
        app_key = _get_secret('API_APP_KEY', '')
        access_key = _get_secret('API_ACCESS_KEY', '')
        resource_id = _get_secret('API_RESOURCE_ID', 'volc.service_type.10053')
        
        # 注意：移除了自动写入Keychain的逻辑，避免不必要的Keychain访问弹窗
        # 内置的app_secrets.json已经提供了开箱即用的体验

        api_config = APIConfig(
            app_key=app_key,
            access_key=access_key,
            resource_id=resource_id,
            ws_url=os.getenv('WS_URL', 'wss://openspeech.bytedance.com/api/v4/ast/v2/translate')
        )
        
        audio_config = AudioConfig(
            sample_rate=int(os.getenv('AUDIO_SAMPLE_RATE', '16000')),
            channels=int(os.getenv('AUDIO_CHANNELS', '1')),
            chunk_ms=int(os.getenv('AUDIO_CHUNK_MS', '80')),
            input_device=(int(os.getenv('AUDIO_INPUT_DEVICE')) if os.getenv('AUDIO_INPUT_DEVICE', '').isdigit() else None),
            output_device=(int(os.getenv('AUDIO_OUTPUT_DEVICE')) if os.getenv('AUDIO_OUTPUT_DEVICE', '').isdigit() else None)
        )
        
        target_audio_config = TargetAudioConfig(
            format=os.getenv('TARGET_AUDIO_FORMAT', 'pcm'),  # 使用PCM格式避免解码
            rate=int(os.getenv('TARGET_AUDIO_RATE', '24000'))
        )
        
        translation_config = TranslationConfig(
            mode=os.getenv('TRANSLATION_MODE', 's2s'),
            source_language=os.getenv('SOURCE_LANGUAGE', 'zh'),
            target_language=os.getenv('TARGET_LANGUAGE', 'en')
        )
        
        config = cls(
            api=api_config,
            audio=audio_config,
            target_audio=target_audio_config,
            translation=translation_config,
            virtual_device_name=os.getenv('VIRTUAL_AUDIO_DEVICE')
        )
        
        # 缓存配置
        if use_cache:
            _config_cache = config
        
        return config
    
    def validate(self) -> bool:
        """验证配置有效性"""
        if not self.api.app_key or not self.api.access_key:
            raise ValueError("API认证信息缺失，请检查.env文件")
        
        if self.translation.source_language == self.translation.target_language:
            raise ValueError("源语言和目标语言不能相同")
        
        if self.translation.source_language not in ['zh', 'en']:
            raise ValueError(f"不支持的源语言: {self.translation.source_language}")
        
        if self.translation.target_language not in ['zh', 'en']:
            raise ValueError(f"不支持的目标语言: {self.translation.target_language}")
        
        return True
