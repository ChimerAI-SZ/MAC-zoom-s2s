#!/usr/bin/env python3
"""
用户偏好持久化：优先使用 NSUserDefaults，回退到本地 JSON。
Babel AI管理项：
- start_on_launch: 是否启动即开始翻译（默认 True）
- conference_mode: 是否启用会议模式（BlackHole 输出）（默认 False）
- language: 'zh-en' 或 'en-zh'（默认 'zh-en'）
- log_level: 'INFO'（默认）
- input_device: int 或 None（默认 None）
- output_device: int 或 None（默认 None）
"""
import os
import json
from typing import Optional

try:
    from Foundation import NSUserDefaults
except Exception:
    NSUserDefaults = None

APP_DOMAIN = 'com.babelai.translator'
FALLBACK_DIR = os.path.expanduser('~/.config/babel-ai')
FALLBACK_PATH = os.path.join(FALLBACK_DIR, 'preferences.json')


def _ensure_fallback_dir():
    os.makedirs(FALLBACK_DIR, exist_ok=True)


def _defaults():
    return {
        'start_on_launch': True,
        'conference_mode': False,
        'language': 'zh-en',
        'log_level': 'INFO',
        'input_device': None,
        'output_device': None,
    }


def _get_store():
    if NSUserDefaults is not None:
        return NSUserDefaults.standardUserDefaults()
    _ensure_fallback_dir()
    if not os.path.exists(FALLBACK_PATH):
        with open(FALLBACK_PATH, 'w') as f:
            json.dump(_defaults(), f)
    return None


def _read_all():
    if NSUserDefaults is not None:
        d = NSUserDefaults.standardUserDefaults().dictionaryRepresentation()
        # 只取我们关心的键
        out = _defaults()
        out.update({
            'start_on_launch': bool(d.get('s2s_start_on_launch', out['start_on_launch'])),
            'conference_mode': bool(d.get('s2s_conference_mode', out['conference_mode'])),
            'language': str(d.get('s2s_language', out['language'])),
            'log_level': str(d.get('s2s_log_level', out['log_level'])),
            'input_device': d.get('s2s_input_device') if d.get('s2s_input_device') is not None else None,
            'output_device': d.get('s2s_output_device') if d.get('s2s_output_device') is not None else None,
        })
        return out
    else:
        try:
            with open(FALLBACK_PATH, 'r') as f:
                data = json.load(f)
        except Exception:
            data = _defaults()
        merged = _defaults()
        merged.update(data)
        return merged


def _write(key: str, value):
    if NSUserDefaults is not None:
        defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject_forKey_(value, f's2s_{key}')
        defaults.synchronize()
    else:
        data = _read_all()
        data[key] = value
        _ensure_fallback_dir()
        with open(FALLBACK_PATH, 'w') as f:
            json.dump(data, f)


def get_start_on_launch() -> bool:
    return _read_all()['start_on_launch']


def set_start_on_launch(v: bool) -> None:
    _write('start_on_launch', bool(v))


def get_conference_mode() -> bool:
    return _read_all()['conference_mode']


def set_conference_mode(v: bool) -> None:
    _write('conference_mode', bool(v))


def get_language() -> str:
    return _read_all()['language']


def set_language(v: str) -> None:
    if v not in ('zh-en', 'en-zh'):
        v = 'zh-en'
    _write('language', v)


def get_log_level() -> str:
    return _read_all()['log_level']


def set_log_level(v: str) -> None:
    _write('log_level', str(v).upper())


def get_input_device() -> Optional[int]:
    return _read_all()['input_device']


def set_input_device(v: Optional[int]) -> None:
    _write('input_device', int(v) if v is not None else None)


def get_output_device() -> Optional[int]:
    return _read_all()['output_device']


def set_output_device(v: Optional[int]) -> None:
    _write('output_device', int(v) if v is not None else None)

