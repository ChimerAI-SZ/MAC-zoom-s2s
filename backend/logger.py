"""
日志配置模块
提供统一的日志记录功能
"""
import logging
import os
import sys
import re
from logging.handlers import RotatingFileHandler
import colorlog
from typing import Optional

LOG_DIR = os.path.expanduser('~/Library/Logs/BabelAI')
LOG_FILE = os.path.join(LOG_DIR, 'babel-ai.log')


class SecretRedactFilter(logging.Filter):
    """过滤日志中的敏感信息（API Keys、HTTP 头部凭证等）。"""
    # 匹配常见敏感键后的取值
    _pattern = re.compile(r'(API_APP_KEY|API_ACCESS_KEY|API_RESOURCE_ID|X-Api-App-Key|X-Api-Access-Key|X-Api-Resource-Id)\s*[:=]\s*([^\s,;]+)', re.IGNORECASE)

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            msg = record.getMessage()
            if msg:
                def repl(m):
                    return f"{m.group(1)}=<REDACTED>"
                redacted = self._pattern.sub(repl, msg)
                # 更新到 record.msg/args 以避免重复格式化
                record.msg = redacted
                record.args = ()
        except Exception:
            pass
        return True


def setup_logger(name: str = 'BabelAI', level: int = logging.INFO) -> logging.Logger:
    """
    设置彩色日志记录器
    
    Args:
        name: 日志记录器名称
        level: 日志级别
    
    Returns:
        配置好的日志记录器
    """
    logger = logging.getLogger(name)
    
    if logger.handlers:
        return logger
    
    logger.setLevel(level)

    # 彩色控制台
    console_handler = logging.StreamHandler(stream=sys.stdout)
    console_handler.setLevel(level)
    
    color_formatter = colorlog.ColoredFormatter(
        '%(log_color)s%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
        log_colors={
            'DEBUG': 'cyan',
            'INFO': 'green',
            'WARNING': 'yellow',
            'ERROR': 'red',
            'CRITICAL': 'red,bg_white',
        }
    )
    
    console_handler.setFormatter(color_formatter)
    console_handler.addFilter(SecretRedactFilter())
    logger.addHandler(console_handler)

    # 文件日志（滚动 10MB x 3个文件）
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        file_handler = RotatingFileHandler(
            LOG_FILE, 
            maxBytes=5 * 1024 * 1024,  # 5MB per file
            backupCount=3,  # Keep 3 backup files (total 20MB max)
            encoding='utf-8'
        )
        file_handler.setLevel(level)
        file_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        file_handler.setFormatter(file_formatter)
        file_handler.addFilter(SecretRedactFilter())
        logger.addHandler(file_handler)
    except Exception:
        # 文件日志失败不应阻塞应用
        pass
    
    return logger

def set_level(level_name: str) -> None:
    """设置全局日志级别，通过名称控制。

    Args:
        level_name: 'DEBUG' | 'INFO' | 'WARNING' | 'ERROR' | 'CRITICAL'
    """
    level = getattr(logging, level_name.upper(), logging.INFO)
    lg = logging.getLogger('BabelAI')
    lg.setLevel(level)
    for h in lg.handlers:
        h.setLevel(level)

# 支持通过环境变量控制日志级别（默认 INFO）
_level_from_env = os.getenv('LOG_LEVEL', 'INFO').upper()
_level = getattr(logging, _level_from_env, logging.INFO)
logger = setup_logger(level=_level)
