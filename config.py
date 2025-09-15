"""
配置管理模块
管理API认证、音频参数等配置
"""
import os
from dataclasses import dataclass
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

@dataclass
class AudioConfig:
    """音频相关配置"""
    sample_rate: int = 16000
    channels: int = 1
    chunk_ms: int = 80
    bits: int = 16
    format: str = "wav"
    codec: str = "raw"
    
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
    def from_env(cls) -> 'Config':
        """从环境变量加载配置"""
        api_config = APIConfig(
            app_key=os.getenv('API_APP_KEY', ''),
            access_key=os.getenv('API_ACCESS_KEY', ''),
            resource_id=os.getenv('API_RESOURCE_ID', 'volc.service_type.10053'),
            ws_url=os.getenv('WS_URL', 'wss://openspeech.bytedance.com/api/v4/ast/v2/translate')
        )
        
        audio_config = AudioConfig(
            sample_rate=int(os.getenv('AUDIO_SAMPLE_RATE', '16000')),
            channels=int(os.getenv('AUDIO_CHANNELS', '1')),
            chunk_ms=int(os.getenv('AUDIO_CHUNK_MS', '80'))
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
        
        return cls(
            api=api_config,
            audio=audio_config,
            target_audio=target_audio_config,
            translation=translation_config,
            virtual_device_name=os.getenv('VIRTUAL_AUDIO_DEVICE')
        )
    
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