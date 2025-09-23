#!/usr/bin/env python3
"""
macOS 菜单栏应用（黑白极简风）：
- Start / Stop 控制后端 SimpleRealtimeTranslator
- Preferences：语言方向、输入/输出设备、日志级别
- Show Subtitles：打开/关闭字幕浮窗
- BlackHole 检测与提示
"""
import threading
import os
import subprocess
import rumps
import sounddevice as sd
from collections import deque
from typing import Optional, List, Tuple
from logger import logger, set_level
import preferences as prefs
from realtime_simple import SimpleRealtimeTranslator
from health_monitor import get_monitor

try:
    from AppKit import NSWindow, NSPanel, NSBackingStoreBuffered, NSTextView, NSScrollView, NSMakeRect, NSFloatingWindowLevel, NSBezelBorder
    try:
        from AppKit import NSWindowStyleMaskTitled as _T, NSWindowStyleMaskClosable as _C, NSWindowStyleMaskResizable as _R
    except Exception:
        from AppKit import NSTitledWindowMask as _T, NSClosableWindowMask as _C, NSResizableWindowMask as _R
except Exception:
    # 允许在无 GUI 环境下导入失败（如CI），但运行时必须存在
    NSWindow = None


class SubtitleWindow:
    def __init__(self, width=520, height=260):
        if NSWindow is None:
            self.window = None
            self.textview = None
            self.scroll = None
            return
        style =  _C | _T | _R
        self.window = NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
            NSMakeRect(100.0, 100.0, float(width), float(height)),
            style,
            NSBackingStoreBuffered,
            False
        )
        self.window.setTitle_("Babel AI Subtitles")
        self.window.setLevel_(NSFloatingWindowLevel)

        self.scroll = NSScrollView.alloc().initWithFrame_(self.window.contentView().frame())
        self.scroll.setBorderType_(NSBezelBorder)
        self.scroll.setHasVerticalScroller_(True)
        self.scroll.setHasHorizontalScroller_(False)
        self.scroll.setAutohidesScrollers_(False)

        self.textview = NSTextView.alloc().initWithFrame_(self.scroll.contentView().frame())
        self.textview.setEditable_(False)
        self.textview.setAutomaticQuoteSubstitutionEnabled_(False)
        self.scroll.setDocumentView_(self.textview)
        self.window.setContentView_(self.scroll)
        
        # Track text for scrolling
        self.auto_scroll = True

    def show(self):
        """显示窗口，确保窗口可见"""
        if self.window:
            try:
                self.window.makeKeyAndOrderFront_(None)
                # 确保窗口在屏幕上
                self.window.setLevel_(NSFloatingWindowLevel)
            except Exception as e:
                logger.error(f"显示字幕窗口时出错: {e}")

    def hide(self):
        if self.window:
            self.window.orderOut_(None)

    def set_text(self, text: str):
        if self.textview:
            # Limit text length to prevent memory growth
            if len(text) > 5000:
                text = text[-5000:]
            
            self.textview.setString_(text)
            
            # Auto-scroll to bottom if enabled
            if self.auto_scroll and self.scroll:
                try:
                    self.textview.scrollRangeToVisible_((len(text), 0))
                except:
                    pass
    
    def clear(self):
        """Clear subtitle text"""
        if self.textview:
            self.textview.setString_("")


class TranslatorManager:
    def __init__(self):
        self.thread: Optional[threading.Thread] = None
        self.loop = None
        self._running = False
        self._starting = False  # 新增：标记是否正在启动中
        self.translator: Optional[SimpleRealtimeTranslator] = None

        self.last_pairs: deque[Tuple[str, str]] = deque(maxlen=30)
        self._src_cache = None
        self._tgt_cache = None
        self._auto_restart_count = 0
        self._max_auto_restart = 3  # 最多自动重启3次
        self._operation_lock = threading.Lock()  # 防止并发操作
        self._stop_event = threading.Event()  # 用于优雅停止
        self.subtitle_window = None  # 字幕窗口引用

    def _on_src(self, text: str):
        self._src_cache = text
        self.last_pairs.append((text, self._tgt_cache or ""))
        # 更新字幕窗口
        if self.subtitle_window:
            try:
                self.subtitle_window.append_text(f"原文: {text}\n")
            except Exception as e:
                logger.debug(f"更新字幕窗口失败: {e}")

    def _on_tgt(self, text: str):
        self._tgt_cache = text
        self.last_pairs.append((self._src_cache or "", text))
        # 更新字幕窗口
        if self.subtitle_window:
            try:
                self.subtitle_window.append_text(f"译文: {text}\n\n")
            except Exception as e:
                logger.debug(f"更新字幕窗口失败: {e}")

    def is_running(self) -> bool:
        return self._running
    
    def is_starting(self) -> bool:
        """检查是否正在启动中"""
        return self._starting

    def start(self, input_device: Optional[int], output_device: Optional[int],
              source_language: str, target_language: str):
        with self._operation_lock:  # 防止并发启动
            if self._running or self._starting:
                logger.debug("Translator already running or starting, skipping start")
                return
            
            self._starting = True  # 标记为启动中
            self._stop_event.clear()
            
            def runner():
                import asyncio
                try:
                    self.translator = SimpleRealtimeTranslator(
                        input_device=input_device,
                        output_device=output_device,
                        source_language=source_language,
                        target_language=target_language,
                        on_source_sentence=self._on_src,
                        on_translation_sentence=self._on_tgt,
                    )
                    # 成功创建translator后，标记为运行中
                    self._running = True
                    self._starting = False
                    logger.info("Translator successfully started")
                    
                    asyncio.run(self.translator.run())
                except Exception as e:
                    logger.error(f"Translator thread error: {e}")
                    self._starting = False  # 启动失败，清除starting状态
                finally:
                    self._running = False
                    self._starting = False  # 确保清除starting状态
                    logger.info("Translator thread ended")

            self.thread = threading.Thread(target=runner, daemon=False)  # 非daemon，确保清理
            self.thread.start()
            logger.info("Translator thread started")

    def stop(self):
        with self._operation_lock:  # 防止并发停止
            if not self._running and not self._starting:
                logger.debug("Translator not running or starting, skipping stop")
                return
            
            logger.info("Stopping translator...")
            self._running = False
            self._starting = False  # 同时清除启动中状态
            self._stop_event.set()  # 通知停止
            
            # 停止翻译器
            try:
                if self.translator:
                    self.translator.stop()
            except Exception as e:
                logger.error(f"Error stopping translator: {e}")
            
            # 等待线程结束，增加超时处理
            if self.thread and self.thread.is_alive():
                self.thread.join(timeout=10.0)
                if self.thread.is_alive():
                    logger.warning("Thread did not stop cleanly within timeout")
            
            self.thread = None
            self.translator = None
            # 重置自动重启计数
            self._auto_restart_count = 0
            logger.info("Translator stopped")


class BabelAIMenuApp(rumps.App):
    def __init__(self):
        super().__init__("Babel AI", title="Babel AI", menu=[])
        
        # 标记权限是否已请求
        self.permission_requested = False
        self.permission_granted = False
        
        # 延迟权限请求到用户主动操作时
        # self._request_microphone_permission()  # 移除初始化时的请求
        
        self.manager = TranslatorManager()
        self.subtitle_window = SubtitleWindow()
        # 连接字幕窗口到管理器
        self.manager.subtitle_window = self.subtitle_window

        # 状态
        # 偏好加载
        lang = prefs.get_language()
        self.source_language, self.target_language = ('zh','en') if lang == 'zh-en' else ('en','zh')
        self.input_device = prefs.get_input_device()
        self.output_device = prefs.get_output_device()
        self.zoom_mode = bool(prefs.get_conference_mode())
        # 应用日志级别
        try:
            set_level(prefs.get_log_level())
        except Exception:
            pass

        # 菜单 - 优化后的结构
        self.start_stop_item = rumps.MenuItem('Start', callback=self.on_toggle_start_stop)
        self.input_device_menu = self._build_input_device_menu()
        self.output_device_menu = self._build_output_device_menu()
        
        self.menu = [
            self.start_stop_item,  # Start/Stop动态切换
            None,
            self.input_device_menu,  # 音频输入设备（主菜单级别）
            self.output_device_menu,  # 音频输出设备（主菜单级别）
            rumps.MenuItem('Language: 中文 → 英文' if lang == 'zh-en' else 'Language: 英文 → 中文', callback=self.on_toggle_language),
            rumps.MenuItem('Conference Mode (Zoom)', callback=self.on_zoom_mode),
            None,
            self._build_subtitles_menu(),  # 字幕相关功能集中
            self._build_settings_menu(),   # 设置菜单（原Preferences）
            None,
            rumps.MenuItem('Health Status…', callback=self.on_health_status),
            rumps.MenuItem('About…', callback=self.on_about),
            None,
            rumps.MenuItem('Quit', callback=self.on_quit)
        ]
        self._refresh_device_defaults()
        self._detect_blackhole()
        # 设置会议模式菜单状态
        try:
            self.menu['Conference Mode (Zoom)'].state = self.zoom_mode
        except Exception:
            pass
        self._timer = rumps.Timer(self._tick_update, 0.3)
        self._timer.start()

        # 若已具备API凭证且允许自动启动，做到打开即用
        try:
            from config import Config
            cfg = Config.from_env()
            has_keys = bool(cfg.api.app_key and cfg.api.access_key)
            if has_keys and prefs.get_start_on_launch():
                try:
                    self.on_start(None)
                except Exception:
                    pass
        except Exception:
            pass

    def _request_microphone_permission_with_delay(self):
        """延迟请求权限，确保UI准备就绪"""
        import time
        
        # 先给用户一个提示
        rumps.notification('Babel AI', '权限请求', '即将请求麦克风权限，请准备点击"允许"')
        
        # 在后台线程中延迟请求
        def delayed_request():
            time.sleep(2)  # 给用户时间看到提示
            # 在主线程中请求权限
            rumps.App._call_on_main_thread(self._request_microphone_permission)
        
        threading.Thread(target=delayed_request, daemon=True).start()
    
    def _request_microphone_permission(self):
        """使用AVFoundation正确请求麦克风权限"""
        try:
            from AVFoundation import AVCaptureDevice, AVMediaTypeAudio
            import objc
            import threading
            
            # 检查当前权限状态
            auth_status = AVCaptureDevice.authorizationStatusForMediaType_(AVMediaTypeAudio)
            
            logger.info(f"Current microphone authorization status: {auth_status}")
            
            if auth_status == 0:  # AVAuthorizationStatusNotDetermined
                logger.info("Requesting microphone permission via AVFoundation...")
                
                # 创建一个事件来等待异步回调
                permission_granted = [False]
                event = threading.Event()
                
                def completion_handler(granted):
                    permission_granted[0] = granted
                    logger.info(f"Permission response: {'granted' if granted else 'denied'}")
                    event.set()
                
                # 请求权限（这会触发系统对话框）
                AVCaptureDevice.requestAccessForMediaType_completionHandler_(
                    AVMediaTypeAudio, 
                    completion_handler
                )
                
                # 等待用户响应（最多30秒）
                event.wait(timeout=30)
                
                if permission_granted[0]:
                    logger.info("Microphone permission granted!")
                    rumps.notification('Babel AI', '', '麦克风权限已授予')
                    self.permission_requested = True
                    self.permission_granted = True
                    # 权限授予后自动继续启动
                    rumps.App._call_on_main_thread(lambda: self.on_start(None))
                else:
                    logger.warning("Microphone permission denied")
                    self.permission_requested = True
                    self.permission_granted = False
                    self._show_permission_guide()
                    
            elif auth_status == 1:  # AVAuthorizationStatusRestricted
                logger.error("Microphone access restricted by system")
                rumps.alert(
                    title='麦克风访问受限',
                    message='系统限制了麦克风访问。请检查家长控制或企业管理设置。'
                )
                
            elif auth_status == 2:  # AVAuthorizationStatusDenied  
                logger.warning("Microphone permission was previously denied")
                self._show_permission_guide()
                
            elif auth_status == 3:  # AVAuthorizationStatusAuthorized
                logger.info("Microphone permission already authorized")
                self.permission_requested = True
                self.permission_granted = True
                
        except ImportError as e:
            logger.error(f"AVFoundation not available: {e}")
            # 回退到sounddevice方法
            self._fallback_permission_request()
        except Exception as e:
            logger.error(f"Permission request failed: {e}")
            self._fallback_permission_request()
    
    def _fallback_permission_request(self):
        """备用方法：使用sounddevice请求权限"""
        try:
            import sounddevice as sd
            logger.info("Using fallback sounddevice permission request")
            # 尝试录音来触发权限
            sd.rec(1, samplerate=16000, channels=1, dtype='float32', blocking=True)
            # 检查是否成功
            if not self._check_microphone_permission():
                self._show_permission_guide()
        except Exception as e:
            logger.error(f"Fallback permission request failed: {e}")
            self._show_permission_guide()
    
    def _check_microphone_permission(self) -> bool:
        """检查麦克风权限状态"""
        try:
            from AVFoundation import AVCaptureDevice, AVMediaTypeAudio
            
            # 使用AVFoundation检查权限状态
            auth_status = AVCaptureDevice.authorizationStatusForMediaType_(AVMediaTypeAudio)
            
            # 3表示AVAuthorizationStatusAuthorized（已授权）
            is_authorized = (auth_status == 3)
            
            logger.debug(f"Microphone permission check: status={auth_status}, authorized={is_authorized}")
            return is_authorized
            
        except ImportError:
            # 如果AVFoundation不可用，回退到sounddevice检查
            try:
                import sounddevice as sd
                devices = sd.query_devices()
                default_input = sd.default.device[0]
                if default_input is not None:
                    return True
                return len([d for d in devices if d['max_input_channels'] > 0]) > 0
            except Exception as e:
                logger.debug(f"Fallback permission check failed: {e}")
                return False
        except Exception as e:
            logger.debug(f"Permission check failed: {e}")
            return False
    
    def _show_permission_guide(self):
        """显示权限设置引导"""
        response = rumps.alert(
            title='需要麦克风权限',
            message=(
                'Babel AI需要麦克风权限才能进行实时翻译。\n\n'
                '请按以下步骤设置：\n'
                '1. 打开系统设置\n'
                '2. 选择"隐私与安全性"\n' 
                '3. 点击"麦克风"\n'
                '4. 找到Babel AI并勾选允许\n'
                '5. 重启Babel AI应用\n\n'
                '点击"打开设置"将自动跳转到麦克风权限页面'
            ),
            ok='打开设置',
            cancel='稍后设置'
        )
        
        if response == 1:  # 用户点击"打开设置"
            try:
                # 直接打开麦克风权限设置页面
                subprocess.run(['open', 'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone'])
            except Exception as e:
                logger.error(f"Failed to open system preferences: {e}")
                # 备用方案：打开系统偏好设置
                try:
                    subprocess.run(['open', '/System/Library/PreferencePanes/Security.prefPane'])
                except:
                    pass

    def _build_input_device_menu(self) -> rumps.MenuItem:
        """构建输入设备菜单（主菜单级别）"""
        devices = sd.query_devices()
        current_device_name = "默认设备"
        
        # 获取当前设备名称
        if self.input_device is not None and self.input_device < len(devices):
            current_device_name = devices[self.input_device]['name']
            if len(current_device_name) > 20:
                current_device_name = current_device_name[:17] + "..."
        
        menu = rumps.MenuItem(f'Input: {current_device_name}')
        
        # 添加默认选项
        default_item = rumps.MenuItem('System Default', callback=lambda _: self._select_input(None))
        if self.input_device is None:
            default_item.state = True
        menu.add(default_item)
        menu.add(rumps.separator)
        
        # 添加所有输入设备
        for idx, device in enumerate(devices):
            if device['max_input_channels'] > 0:
                name = device['name']
                # 为输入设备添加麦克风图标
                display_name = "🎤 " + name
                if len(display_name) > 30:
                    display_name = display_name[:27] + "..."
                
                item = rumps.MenuItem(display_name, callback=lambda _, i=idx: self._select_input(i))
                if self.input_device == idx:
                    item.state = True
                menu.add(item)
        
        return menu
    
    def _build_output_device_menu(self) -> rumps.MenuItem:
        """构建输出设备菜单（主菜单级别）"""
        devices = sd.query_devices()
        current_device_name = "默认设备"
        
        # 获取当前设备名称
        if self.output_device is not None and self.output_device < len(devices):
            current_device_name = devices[self.output_device]['name']
            if len(current_device_name) > 20:
                current_device_name = current_device_name[:17] + "..."
        
        menu = rumps.MenuItem(f'Output: {current_device_name}')
        
        # 添加默认选项
        default_item = rumps.MenuItem('System Default', callback=lambda _: self._select_output(None))
        if self.output_device is None:
            default_item.state = True
        menu.add(default_item)
        menu.add(rumps.separator)
        
        # 添加所有输出设备
        for idx, device in enumerate(devices):
            if device['max_output_channels'] > 0:
                name = device['name']
                display_name = name
                if len(display_name) > 30:
                    display_name = display_name[:27] + "..."
                
                item = rumps.MenuItem(display_name, callback=lambda _, i=idx: self._select_output(i))
                if self.output_device == idx:
                    item.state = True
                menu.add(item)
        
        return menu
    
    def _build_subtitles_menu(self) -> rumps.MenuItem:
        """构建字幕子菜单"""
        menu = rumps.MenuItem('Subtitles')
        menu.add(rumps.MenuItem('Show Window', callback=self.on_show_subtitles))
        menu.add(rumps.MenuItem('Clear Text', callback=self.on_clear_subtitles))
        # 未来可以添加更多选项如：Auto-scroll, Font Size等
        return menu
    
    def _build_settings_menu(self) -> rumps.MenuItem:
        """构建设置菜单（替代原Preferences）"""
        menu = rumps.MenuItem('Settings')
        
        # 启动即开始
        start_on_launch = rumps.MenuItem('Start on Launch', callback=self.on_start_on_launch)
        start_on_launch.state = prefs.get_start_on_launch()
        menu.add(start_on_launch)
        
        # 日志级别
        log_menu = rumps.MenuItem('Log Level')
        current_level = prefs.get_log_level()
        for lvl in ['DEBUG', 'INFO', 'WARNING', 'ERROR']:
            item = rumps.MenuItem(lvl, callback=lambda s, l=lvl: self._set_log_level(l))
            if lvl == current_level:
                item.state = True
            log_menu.add(item)
        menu.add(log_menu)
        
        menu.add(rumps.separator)
        
        # 高级设置
        advanced_menu = rumps.MenuItem('Advanced')
        advanced_menu.add(rumps.MenuItem('API Configuration…', callback=self.on_api_keys))
        advanced_menu.add(rumps.MenuItem('Reset to Defaults', callback=self.on_reset_defaults))
        menu.add(advanced_menu)
        
        return menu


    def _refresh_device_defaults(self):
        try:
            di, do = sd.default.device
            self.input_device = di
            self.output_device = do
            # 不覆盖用户偏好中已指定的非空值
            if prefs.get_input_device() is not None:
                self.input_device = prefs.get_input_device()
            if prefs.get_output_device() is not None:
                self.output_device = prefs.get_output_device()
        except Exception:
            pass

    def _detect_blackhole(self):
        try:
            devices = sd.query_devices()
            found = any('BlackHole' in d['name'] and d['max_output_channels'] > 0 for d in devices)
            if not found:
                # 尝试自动安装（优先使用内置PKG；其次 Homebrew；最后打开文档）
                self._try_install_blackhole()
        except Exception:
            pass

    def _brew_path(self) -> Optional[str]:
        for p in ['/opt/homebrew/bin/brew', '/usr/local/bin/brew']:
            if os.path.exists(p):
                return p
        return None

    def _try_install_blackhole(self):
        # 已安装直接返回
        if any('BlackHole' in d['name'] and d['max_output_channels'] > 0 for d in sd.query_devices()):
            return
        # 1) 内置PKG安装
        app_dir = os.path.dirname(os.path.abspath(__file__))
        pkg = os.path.join(app_dir, 'resources', 'BlackHole2ch.pkg')
        if os.path.exists(pkg):
            script = f'do shell script "/usr/sbin/installer -pkg \"{pkg}\" -target /" with administrator privileges'
            try:
                subprocess.run(['osascript', '-e', script], check=True)
                rumps.notification('Babel AI', '', 'BlackHole 已安装，切换会议模式即可使用')
                return
            except Exception:
                pass
        # 2) Homebrew 安装
        brew = self._brew_path()
        if brew:
            script = f'do shell script "{brew} install --cask blackhole-2ch"'
            try:
                subprocess.run(['osascript', '-e', script], check=True)
                rumps.notification('Babel AI', '', 'BlackHole 已通过 Homebrew 安装')
                return
            except Exception:
                pass
        # 3) 回退：打开配置指南
        btn = rumps.alert(title='BlackHole 未检测到', message='自动安装失败。是否查看配置指南？', ok='打开指南', cancel='关闭')
        if btn == 1:
            try:
                subprocess.run(['open', 'setup_blackhole.md'])
            except Exception:
                pass

    def on_toggle_language(self, menu_item):
        if self.source_language == 'zh':
            self.source_language, self.target_language = 'en', 'zh'
            menu_item.title = 'Language: 英文 → 中文'
            rumps.notification('Preferences', '', '语言方向: 英文 → 中文')
        else:
            self.source_language, self.target_language = 'zh', 'en'
            menu_item.title = 'Language: 中文 → 英文'
            rumps.notification('Preferences', '', '语言方向: 中文 → 英文')
        prefs.set_language('zh-en' if self.source_language=='zh' else 'en-zh')
        if self.manager.is_running():
            self._restart_translator()

    def _update_device_menu_titles(self):
        """更新设备菜单的标题显示当前设备"""
        devices = sd.query_devices()
        
        # 更新输入设备菜单标题
        if self.input_device is None:
            input_name = "默认设备"
        elif self.input_device < len(devices):
            input_name = devices[self.input_device]['name']
            if len(input_name) > 20:
                input_name = input_name[:17] + "..."
        else:
            input_name = "未知设备"
        self.input_device_menu.title = f'Input: {input_name}'
        
        # 更新输出设备菜单标题
        if self.output_device is None:
            output_name = "默认设备"
        elif self.output_device < len(devices):
            output_name = devices[self.output_device]['name']
            if len(output_name) > 20:
                output_name = output_name[:17] + "..."
        else:
            output_name = "未知设备"
        self.output_device_menu.title = f'Output: {output_name}'
    
    def _select_input(self, idx: Optional[int]):
        """选择输入设备，支持None（系统默认）"""
        self.input_device = idx
        
        # 获取设备名称用于通知
        if idx is None:
            device_name = "系统默认"
        else:
            devices = sd.query_devices()
            if idx < len(devices):
                device_name = devices[idx]['name']
            else:
                device_name = f"设备 {idx}"
        
        rumps.notification('Babel AI', '', f'输入设备: {device_name}')
        prefs.set_input_device(idx)
        
        # 更新菜单项的选中状态
        for item in self.input_device_menu.values():
            if hasattr(item, 'state'):
                item.state = False
        
        if idx is None:
            if 'System Default' in self.input_device_menu:
                self.input_device_menu['System Default'].state = True
        else:
            # 找到对应的设备项并设置为选中
            devices = sd.query_devices()
            if idx < len(devices):
                device_name = devices[idx]['name']
                if len(device_name) > 30:
                    device_name = device_name[:27] + "..."
                if device_name in self.input_device_menu:
                    self.input_device_menu[device_name].state = True
        
        if self.manager.is_running():
            self._restart_translator()

    def _select_output(self, idx: Optional[int]):
        """选择输出设备，支持None（系统默认）"""
        self.output_device = idx
        
        # 获取设备名称用于通知
        if idx is None:
            device_name = "系统默认"
        else:
            devices = sd.query_devices()
            if idx < len(devices):
                device_name = devices[idx]['name']
            else:
                device_name = f"设备 {idx}"
        
        rumps.notification('Babel AI', '', f'输出设备: {device_name}')
        prefs.set_output_device(idx)
        
        # 更新菜单项的选中状态
        for item in self.output_device_menu.values():
            if hasattr(item, 'state'):
                item.state = False
        
        if idx is None:
            if 'System Default' in self.output_device_menu:
                self.output_device_menu['System Default'].state = True
        else:
            # 找到对应的设备项并设置为选中
            devices = sd.query_devices()
            if idx < len(devices):
                device_name = devices[idx]['name']
                if len(device_name) > 30:
                    device_name = device_name[:27] + "..."
                if device_name in self.output_device_menu:
                    self.output_device_menu[device_name].state = True
        
        if self.manager.is_running():
            self._restart_translator()

    def on_zoom_mode(self, menu_item):
        menu_item.state = not menu_item.state
        self.zoom_mode = menu_item.state
        if self.zoom_mode:
            # 会议模式：输入使用麦克风，输出使用 BlackHole
            devices = sd.query_devices()
            
            # 确保输入设备使用系统默认麦克风
            default_input = sd.default.device[0]
            self.input_device = default_input
            logger.info(f"会议模式 - 输入设备: [{default_input}] {devices[default_input]['name'] if default_input else '系统默认'}")
            
            # 查找 BlackHole 作为输出
            idx = next((i for i, d in enumerate(devices) if 'BlackHole' in d['name'] and d['max_output_channels'] > 0), None)
            if idx is None:
                self._try_install_blackhole()
                devices = sd.query_devices()
                idx = next((i for i, d in enumerate(devices) if 'BlackHole' in d['name'] and d['max_output_channels'] > 0), None)
                if idx is None:
                    rumps.notification('Babel AI', '', '仍未检测到 BlackHole，请按指南手动安装')
                    return
            else:
                self.output_device = idx
                input_name = devices[default_input]['name'] if default_input else '系统默认'
                output_name = devices[idx]['name'] if idx else 'BlackHole'
                logger.info(f"会议模式 - 输出设备: [{idx}] {output_name}")
                
                # 显示配置指南
                message = (
                    "会议模式已启用！\n\n"
                    "Babel AI 设置:\n"
                    f"• 输入: {input_name} (麦克风)\n"
                    f"• 输出: {output_name}\n\n"
                    "会议软件设置:\n"
                    "• 麦克风: BlackHole 2ch\n"
                    "• 扬声器: 系统默认 (耳机/扬声器)\n\n"
                    "这样您说话会被翻译并传入会议"
                )
                rumps.alert(title='会议模式配置', message=message, ok='明白了')
            prefs.set_conference_mode(True)
            prefs.set_input_device(self.input_device)
            prefs.set_output_device(self.output_device)
        else:
            self._refresh_device_defaults()
            rumps.notification('Babel AI', '', '会议模式已关闭，恢复为系统默认输出')
            prefs.set_conference_mode(False)
        if self.manager.is_running():
            self._restart_translator()

    def on_start_on_launch(self, menu_item):
        menu_item.state = not menu_item.state
        prefs.set_start_on_launch(bool(menu_item.state))
        rumps.notification('Babel AI', '', '启动即开始：已开启' if menu_item.state else '启动即开始：已关闭')

    def _set_log_level(self, level: str):
        try:
            set_level(level)
            prefs.set_log_level(level)
            rumps.notification('Babel AI', '', f'日志级别：{level}')
        except Exception:
            pass


    def on_toggle_start_stop(self, _):
        """合并的Start/Stop切换功能"""
        if self.manager.is_running():
            self.on_stop(_)
        else:
            self.on_start(_)
    
    def on_reset_defaults(self, _):
        """重置为默认设置"""
        response = rumps.alert(
            title='重置设置',
            message='确定要重置所有设置为默认值吗？',
            ok='重置',
            cancel='取消'
        )
        if response == 1:  # 用户点击重置
            # 重置设备为系统默认
            self.input_device = None
            self.output_device = None
            prefs.set_input_device(None)
            prefs.set_output_device(None)
            
            # 重置语言为中文→英文
            self.source_language = 'zh'
            self.target_language = 'en'
            prefs.set_language('zh-en')
            
            # 重置其他设置
            prefs.set_conference_mode(False)
            prefs.set_start_on_launch(True)
            prefs.set_log_level('INFO')
            
            rumps.notification('Babel AI', '', '设置已重置为默认值')
            
            # 如果正在运行，重启翻译器
            if self.manager.is_running():
                self._restart_translator()
    
    def on_api_keys(self, _):
        """改进的API密钥配置对话框"""
        try:
            import keyring
        except Exception:
            rumps.alert('无法使用 Keychain，请确认依赖已安装')
            return
        
        # 检查当前配置状态
        try:
            from config import Config
            cfg = Config.from_env()
            has_keys = bool(cfg.api.app_key and cfg.api.access_key)
        except:
            has_keys = False
        status_msg = "✓ 已配置" if has_keys else "✗ 未配置"
        
        # 显示说明对话框
        response = rumps.alert(
            title='API 配置',
            message=f'当前状态: {status_msg}\n\n点击"继续"配置API密钥\n留空的项将保持不变',
            ok='继续',
            cancel='取消'
        )
        
        if response == 0:  # 用户取消
            return
        
        # 获取现有密钥（用于显示提示）
        existing_app_key = ""
        existing_access_key = ""
        existing_resource_id = "volc.service_type.10053"
        
        try:
            if keyring:
                existing_app_key = keyring.get_password('Babel AI', 'API_APP_KEY') or ""
                existing_access_key = keyring.get_password('Babel AI', 'API_ACCESS_KEY') or ""
                existing_resource_id = keyring.get_password('Babel AI', 'API_RESOURCE_ID') or existing_resource_id
        except:
            pass
        
        # 逐个输入，但允许取消
        app_key_window = rumps.Window(
            '请输入 API_APP_KEY',
            'API配置 (1/3)',
            default_text='',
            dimensions=(320, 24)
        )
        app_key_response = app_key_window.run()
        if not app_key_response.clicked:  # 用户取消
            return
        
        access_key_window = rumps.Window(
            '请输入 API_ACCESS_KEY',
            'API配置 (2/3)',
            default_text='',
            dimensions=(320, 24)
        )
        access_key_response = access_key_window.run()
        if not access_key_response.clicked:  # 用户取消
            return
        
        resource_id_window = rumps.Window(
            '请输入 API_RESOURCE_ID',
            'API配置 (3/3)',
            default_text=existing_resource_id,
            dimensions=(320, 24)
        )
        resource_id_response = resource_id_window.run()
        if not resource_id_response.clicked:  # 用户取消
            return
        
        # 保存配置（只更新非空值）
        try:
            if app_key_response.text.strip():
                keyring.set_password('Babel AI', 'API_APP_KEY', app_key_response.text.strip())
            if access_key_response.text.strip():
                keyring.set_password('Babel AI', 'API_ACCESS_KEY', access_key_response.text.strip())
            if resource_id_response.text.strip():
                keyring.set_password('Babel AI', 'API_RESOURCE_ID', resource_id_response.text.strip())
            
            # 清除配置缓存，确保下次加载新的密钥
            import config
            config._config_cache = None
            
            rumps.notification('Babel AI', '', 'API配置已保存到 Keychain')
        except Exception as e:
            rumps.alert(f'保存失败: {e}')

    def _restart_translator(self):
        # 确保stop完全完成后再start
        logger.info("Restarting translator...")
        self.on_stop(None)
        # 等待一小段时间确保资源释放
        import time
        time.sleep(0.5)
        self.on_start(None)
        logger.info("Translator restarted")

    def on_start(self, _):
        if not self.manager.is_running():
            # 首先检查并请求麦克风权限
            if not self.permission_requested:
                self._request_microphone_permission_with_delay()
                return  # 权限请求后会自动重试启动
            
            # 检查权限是否已授予
            if not self._check_microphone_permission():
                self._show_permission_guide()
                return
            
            # 一次性验证API密钥（使用缓存的配置）
            try:
                from config import Config
                cfg = Config.from_env()  # 使用缓存，避免多次访问
                
                # 检查API密钥是否存在
                if not cfg.api.app_key or not cfg.api.access_key:
                    rumps.alert(
                        title='API密钥缺失',
                        message='请先在 Preferences → API Keys 中配置API密钥',
                        ok='确定'
                    )
                    return
                
                # 基本长度验证
                if len(cfg.api.app_key) < 10 or len(cfg.api.access_key) < 10:
                    rumps.alert(
                        title='API密钥可能无效',
                        message='API密钥长度异常，请检查配置',
                        ok='确定'
                    )
                    return
                    
            except Exception as e:
                logger.error(f'验证API密钥失败: {e}')
                rumps.alert(
                    title='配置错误',
                    message=f'无法验证配置: {str(e)}',
                    ok='确定'
                )
                return
            
            logger.info(f'Starting translator with devices: input={self.input_device}, output={self.output_device}')
            logger.info(f'Languages: {self.source_language} -> {self.target_language}')
            self.manager.start(self.input_device, self.output_device,
                               self.source_language, self.target_language)
            rumps.notification('Babel AI', '', '已启动')

    def on_stop(self, _):
        if self.manager.is_running():
            logger.info('Stopping translator...')
            self.manager.stop()
            rumps.notification('Babel AI', '', '已停止')

    def on_show_subtitles(self, _):
        """显示字幕窗口，如果窗口已关闭则重新创建"""
        try:
            # 检查窗口是否真正可用
            if self.subtitle_window and self.subtitle_window.window:
                # 尝试检查窗口是否可见
                try:
                    # 如果窗口还在，直接显示
                    self.subtitle_window.show()
                    return
                except Exception:
                    # 窗口已不可用，需要重建
                    pass
            
            # 重新创建字幕窗口
            self.subtitle_window = SubtitleWindow()
            # 更新管理器的引用
            self.manager.subtitle_window = self.subtitle_window
            self.subtitle_window.show()
                
        except Exception as e:
            logger.error(f"显示字幕窗口失败: {e}")
            # 确保重建窗口
            try:
                self.subtitle_window = SubtitleWindow()
                # 更新管理器的引用
                self.manager.subtitle_window = self.subtitle_window
                self.subtitle_window.show()
            except Exception as e2:
                logger.error(f"重建字幕窗口失败: {e2}")
    
    def on_clear_subtitles(self, _):
        """Clear subtitle window text"""
        if self.subtitle_window:
            self.subtitle_window.clear()
            # Also clear the buffer
            self.manager.last_pairs.clear()
    
    def on_about(self, _):
        """Show about dialog"""
        rumps.alert(
            title='关于 Babel AI',
            message=(
                'Babel AI - 实时语音翻译系统\n'
                '版本: 1.0.0\n'
                '\n'
                '支持中英双向实时语音翻译\n'
                '使用字节跳动语音翻译API\n'
                '\n'
                '© 2025 Babel AI Team'
            ),
            ok='确定'
        )
    
    def on_health_status(self, _):
        """显示健康状态"""
        monitor = get_monitor()
        status = monitor.get_health_status()
        metrics = status['metrics']
        
        # 构建状态信息
        info_lines = [
            f"状态: {'✅ 健康' if status['healthy'] else '⚠️ 异常'}",
            f"运行时间: {status['uptime']:.1f}秒",
            f"会话状态: {metrics['session_state']}",
            "",
            f"内存使用: {metrics['memory_usage_mb']:.1f}MB ({metrics['memory_percent']:.1f}%)",
            f"线程数: {metrics['thread_count']}",
            f"活动任务: {metrics['active_tasks']}",
            "",
            f"音频缓冲: {metrics['audio_buffer_size']}块",
            f"发送队列: {metrics['send_queue_size']}项",
            "",
            f"WebSocket延迟: {metrics['websocket_ping_ms']:.1f}ms",
            f"已处理句子: {metrics['total_sentences']}",
            f"重连次数: {metrics['reconnect_count']}",
            f"错误次数: {metrics['error_count']}"
        ]
        
        rumps.alert(
            title='Babel AI 健康状态',
            message='\n'.join(info_lines),
            ok='关闭'
        )

    def _tick_update(self, _):
        # 更新Start/Stop按钮文字
        if self.manager.is_starting():
            self.start_stop_item.title = 'Starting...'
        elif self.manager.is_running():
            self.start_stop_item.title = 'Stop'
        else:
            self.start_stop_item.title = 'Start'
        
        # 更新设备菜单标题
        self._update_device_menu_titles()
        
        # 更新菜单标题和字幕内容
        # 增强状态显示
        if self.manager.is_starting():
            self.title = 'Babel AI ◐'  # 启动中显示半圆
        elif not self.manager.is_running():
            self.title = 'Babel AI ○'
        else:
            # 检查健康状态
            monitor = get_monitor()
            state = monitor.get_health_status()['state']
            if state == 'error':
                self.title = 'Babel AI ⚠'
            elif state == 'connecting' or state == 'reconnecting':
                self.title = 'Babel AI ◐'
            else:
                self.title = 'Babel AI ●'
        
        # 后端线程看门狗：若异常退出，自动重启（有次数限制）
        if self.manager._running and (self.manager.thread is None or not self.manager.thread.is_alive()):
            if self.manager._auto_restart_count < self.manager._max_auto_restart:
                self.manager._auto_restart_count += 1
                logger.warning(f'检测到后端线程已退出，正在自动恢复...（第{self.manager._auto_restart_count}次）')
                try:
                    # 先清理状态
                    self.manager._running = False
                    # 重新启动
                    self.manager.start(self.input_device, self.output_device,
                                       self.source_language, self.target_language)
                    rumps.notification('Babel AI', '', f'后台已恢复运行（第{self.manager._auto_restart_count}次）')
                except Exception as e:
                    logger.error(f'自动恢复失败: {e}')
                    rumps.notification('Babel AI', '', '后台恢复失败，请手动点击 Start')
            elif self.manager._auto_restart_count == self.manager._max_auto_restart:
                self.manager._auto_restart_count += 1  # 防止重复通知
                logger.error('自动重启次数已达上限，停止自动恢复')
                rumps.notification('Babel AI', '', '多次恢复失败，请检查配置并手动重启')
        
        # 更新字幕窗口（限制文本长度）
        if self.subtitle_window and self.subtitle_window.window:
            lines = []
            # 只保留最近20对，每100次更新清理一次
            display_pairs = list(self.manager.last_pairs)[-20:]
            for src, tgt in display_pairs:
                if src:
                    # 限制单行长度
                    if len(src) > 100:
                        src = src[:97] + '...'
                    lines.append(f'[原文] {src}')
                if tgt:
                    if len(tgt) > 100:
                        tgt = tgt[:97] + '...'
                    lines.append(f'[翻译] {tgt}')
            
            # 限制总行数为100行
            if len(lines) > 100:
                lines = lines[-100:]
            
            self.subtitle_window.set_text('\n'.join(lines))

    def on_quit(self, _):
        try:
            self.on_stop(_)
        finally:
            rumps.quit_application()


def main():
    BabelAIMenuApp().run()


if __name__ == '__main__':
    main()
