#!/usr/bin/env python3
"""
快速验证健壮性改进是否生效
"""
import sys
import os
# 添加父目录到路径，以便导入主项目模块
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import importlib


def verify_imports():
    """验证所有模块可以正常导入"""
    modules_to_check = [
        'health_monitor',
        'app_menu',
        'realtime_simple',
        'psutil'
    ]
    
    print("检查模块导入...")
    for module_name in modules_to_check:
        try:
            importlib.import_module(module_name)
            print(f"  ✅ {module_name}")
        except ImportError as e:
            print(f"  ❌ {module_name}: {e}")
            return False
    return True


def verify_health_monitor():
    """验证健康监控功能"""
    print("\n检查健康监控...")
    try:
        from health_monitor import get_monitor, SessionState
        
        monitor = get_monitor()
        monitor.start()
        
        # 测试各种功能
        monitor.update_session_state(SessionState.IDLE)
        monitor.update_buffer_size(10, 20)
        monitor.record_error("Test error")
        monitor.record_reconnect()
        monitor.record_sentence()
        
        # 获取状态
        status = monitor.get_health_status()
        
        print(f"  ✅ 健康状态: {status['healthy']}")
        print(f"  ✅ 内存使用: {status['metrics']['memory_usage_mb']:.1f}MB")
        print(f"  ✅ 线程数: {status['metrics']['thread_count']}")
        
        monitor.stop()
        return True
        
    except Exception as e:
        print(f"  ❌ 健康监控错误: {e}")
        return False


def verify_thread_safety():
    """验证线程安全改进"""
    print("\n检查线程安全...")
    try:
        from app_menu import TranslatorManager
        import threading
        
        manager = TranslatorManager()
        
        # 检查锁是否存在
        assert hasattr(manager, '_operation_lock'), "缺少操作锁"
        assert hasattr(manager, '_stop_event'), "缺少停止事件"
        assert hasattr(manager, '_max_auto_restart'), "缺少重启限制"
        
        print(f"  ✅ 操作锁: {type(manager._operation_lock)}")
        print(f"  ✅ 停止事件: {type(manager._stop_event)}")
        print(f"  ✅ 最大重启次数: {manager._max_auto_restart}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ 线程安全检查失败: {e}")
        return False


def verify_resource_limits():
    """验证资源限制"""
    print("\n检查资源限制...")
    try:
        from realtime_simple import SimplePCMPlayer, SimpleRealtimeTranslator
        
        # 检查播放器缓冲区限制
        player = SimplePCMPlayer()
        assert hasattr(player, 'max_buffer_size'), "缺少缓冲区大小限制"
        print(f"  ✅ 音频缓冲区限制: {player.max_buffer_size}块")
        
        # 检查翻译器队列限制
        translator = SimpleRealtimeTranslator()
        assert hasattr(translator, 'max_queue_size'), "缺少队列大小限制"
        print(f"  ✅ 发送队列限制: {translator.max_queue_size}项")
        
        return True
        
    except Exception as e:
        print(f"  ❌ 资源限制检查失败: {e}")
        return False


def main():
    print("="*50)
    print("S2S 健壮性改进验证")
    print("="*50)
    
    all_passed = True
    
    # 运行各项验证
    all_passed &= verify_imports()
    all_passed &= verify_health_monitor()
    all_passed &= verify_thread_safety()
    all_passed &= verify_resource_limits()
    
    print("\n" + "="*50)
    if all_passed:
        print("✅ 所有验证通过！健壮性改进已成功实施。")
        print("\n建议：")
        print("1. 运行 python test_robustness.py 进行完整测试")
        print("2. 启动应用并查看 Health Status 菜单项")
        print("3. 查看 ROBUSTNESS_IMPROVEMENTS.md 了解详细改进")
    else:
        print("❌ 部分验证失败，请检查错误信息。")
        sys.exit(1)


if __name__ == "__main__":
    main()