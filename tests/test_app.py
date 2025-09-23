#!/usr/bin/env python3
"""
快速验证应用是否可以正常启动
在构建前运行此脚本，可以提前发现启动问题
"""
import sys
import os

def test_imports():
    """测试所有关键模块是否能正常导入"""
    print("1. 测试导入模块...")
    try:
        import config
        print("   ✅ config模块导入成功")
    except Exception as e:
        print(f"   ❌ config模块导入失败: {e}")
        return False
    
    try:
        import app_menu
        print("   ✅ app_menu模块导入成功")
    except Exception as e:
        print(f"   ❌ app_menu模块导入失败: {e}")
        return False
    
    try:
        import realtime_simple
        print("   ✅ realtime_simple模块导入成功")
    except Exception as e:
        print(f"   ❌ realtime_simple模块导入失败: {e}")
        return False
    
    try:
        import logger
        print("   ✅ logger模块导入成功")
    except Exception as e:
        print(f"   ❌ logger模块导入失败: {e}")
        return False
    
    try:
        import preferences
        print("   ✅ preferences模块导入成功")
    except Exception as e:
        print(f"   ❌ preferences模块导入失败: {e}")
        return False
    
    return True

def test_config():
    """测试配置是否能正常加载"""
    print("\n2. 测试配置加载...")
    try:
        from config import Config
        cfg = Config.from_env()
        
        # 检查API密钥
        if cfg.api.app_key:
            print(f"   ✅ API App Key已配置 (长度: {len(cfg.api.app_key)})")
        else:
            print("   ⚠️  API App Key未配置")
        
        if cfg.api.access_key:
            print(f"   ✅ API Access Key已配置 (长度: {len(cfg.api.access_key)})")
        else:
            print("   ⚠️  API Access Key未配置")
        
        if cfg.api.resource_id:
            print(f"   ✅ API Resource ID已配置: {cfg.api.resource_id}")
        else:
            print("   ⚠️  API Resource ID未配置")
        
        # 测试配置缓存
        print("\n3. 测试配置缓存...")
        cfg2 = Config.from_env()
        if cfg is cfg2:
            print("   ✅ 配置缓存工作正常")
        else:
            print("   ⚠️  配置缓存未生效")
        
        return True
    except Exception as e:
        print(f"   ❌ 配置加载失败: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_dependencies():
    """测试关键依赖是否安装"""
    print("\n4. 测试关键依赖...")
    deps_ok = True
    
    try:
        import rumps
        print("   ✅ rumps (菜单栏) 已安装")
    except ImportError:
        print("   ❌ rumps未安装")
        deps_ok = False
    
    try:
        import sounddevice
        print("   ✅ sounddevice (音频) 已安装")
    except ImportError:
        print("   ❌ sounddevice未安装")
        deps_ok = False
    
    try:
        import websockets
        print("   ✅ websockets已安装")
    except ImportError:
        print("   ❌ websockets未安装")
        deps_ok = False
    
    try:
        import numpy
        print("   ✅ numpy已安装")
    except ImportError:
        print("   ❌ numpy未安装")
        deps_ok = False
    
    return deps_ok

def main():
    """主测试函数"""
    print("="*50)
    print("S2S 应用启动验证")
    print("="*50)
    
    # 切换到脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    print(f"工作目录: {os.getcwd()}\n")
    
    # 执行测试
    all_ok = True
    
    if not test_imports():
        all_ok = False
    
    if not test_config():
        all_ok = False
    
    if not test_dependencies():
        all_ok = False
    
    # 输出结果
    print("\n" + "="*50)
    if all_ok:
        print("✅ 所有测试通过，应用可以正常启动！")
        print("\n下一步:")
        print("1. 测试运行: python app_menu.py")
        print("2. 构建应用: make app")
        sys.exit(0)
    else:
        print("❌ 测试失败，请修复上述问题后重试")
        sys.exit(1)

if __name__ == "__main__":
    main()