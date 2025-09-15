#!/usr/bin/env python3
"""
一键启动脚本 - 自动检查环境并运行实时翻译系统
"""
import subprocess
import sys
import os
from pathlib import Path

def check_python_version():
    """检查Python版本"""
    if sys.version_info < (3, 8):
        print("❌ 需要 Python 3.8 或更高版本")
        print(f"   当前版本: {sys.version}")
        sys.exit(1)
    print(f"✅ Python版本: {sys.version.split()[0]}")

def check_env_file():
    """检查.env配置文件"""
    env_file = Path(".env")
    env_example = Path(".env.example")
    
    if not env_file.exists():
        print("\n⚠️  未找到 .env 文件")
        
        if env_example.exists():
            print("📝 请按以下步骤配置:")
            print("   1. 复制 .env.example 为 .env")
            print("   2. 编辑 .env 文件，填入您的 ByteDance API 凭证")
            print("\n示例命令:")
            print("   cp .env.example .env")
            print("   # 然后编辑 .env 文件")
        else:
            print("请创建 .env 文件并添加以下内容:")
            print("API_APP_KEY=your_app_key_here")
            print("API_ACCESS_KEY=your_access_key_here")
            print("API_RESOURCE_ID=your_resource_id_here")
        
        sys.exit(1)
    
    # 检查必要的配置项
    with open(env_file, 'r') as f:
        content = f.read()
        
    required_keys = ['API_APP_KEY', 'API_ACCESS_KEY', 'API_RESOURCE_ID']
    missing_keys = []
    
    for key in required_keys:
        if key not in content or f"{key}=your" in content or f"{key}=" in content and content.split(f"{key}=")[1].split('\n')[0].strip() == '':
            missing_keys.append(key)
    
    if missing_keys:
        print("\n⚠️  请在 .env 文件中配置以下 API 凭证:")
        for key in missing_keys:
            print(f"   - {key}")
        print("\n💡 提示: 从 https://console.volcengine.com/ 获取您的 API 凭证")
        sys.exit(1)
    
    print("✅ 配置文件已就绪")

def install_dependencies():
    """安装依赖包"""
    print("\n📦 检查依赖包...")
    
    # 检查是否存在虚拟环境
    venv_path = Path("venv")
    if venv_path.exists():
        print("   使用已存在的虚拟环境")
        if sys.platform == "win32":
            python_exe = venv_path / "Scripts" / "python.exe"
        else:
            python_exe = venv_path / "bin" / "python"
        
        if python_exe.exists():
            # 在虚拟环境中安装依赖
            subprocess.run([str(python_exe), "-m", "pip", "install", "-q", "-r", "requirements.txt"])
            return str(python_exe)
    
    # 在当前环境中检查并安装依赖
    try:
        import sounddevice
        import websockets
        import numpy
        print("   依赖包已安装")
    except ImportError:
        print("   正在安装依赖包...")
        result = subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"], 
                              capture_output=True, text=True)
        if result.returncode != 0:
            print("❌ 依赖安装失败")
            print(result.stderr)
            sys.exit(1)
        print("   ✅ 依赖包安装完成")
    
    return sys.executable

def check_audio_devices():
    """检查音频设备"""
    print("\n🎤 检查音频设备...")
    try:
        import sounddevice as sd
        devices = sd.query_devices()
        input_devices = [d for d in devices if d['max_input_channels'] > 0]
        
        if not input_devices:
            print("❌ 未找到可用的麦克风设备")
            print("   请确保已连接麦克风")
            sys.exit(1)
        
        default_input = sd.default.device[0]
        if default_input is not None and default_input < len(devices):
            print(f"   默认麦克风: {devices[default_input]['name']}")
        else:
            print(f"   找到 {len(input_devices)} 个麦克风设备")
    
    except Exception as e:
        print(f"⚠️  无法检查音频设备: {e}")
        print("   继续运行，但可能遇到音频问题")

def run_translator(python_exe):
    """运行翻译程序"""
    print("\n" + "="*50)
    print("🚀 启动实时语音翻译系统")
    print("="*50)
    print("\n功能说明:")
    print("  • 中文语音 → 英文语音")
    print("  • 实时翻译，低延迟")
    print("  • 按 Ctrl+C 退出\n")
    print("="*50 + "\n")
    
    try:
        subprocess.run([python_exe, "realtime_simple.py"])
    except KeyboardInterrupt:
        print("\n\n👋 感谢使用，再见！")
    except Exception as e:
        print(f"\n❌ 运行出错: {e}")
        sys.exit(1)

def main():
    """主函数"""
    print("🔧 实时语音翻译系统 - 启动检查")
    print("="*50)
    
    # 切换到脚本所在目录
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    # 执行检查
    check_python_version()
    check_env_file()
    python_exe = install_dependencies()
    check_audio_devices()
    
    # 运行程序
    run_translator(python_exe)

if __name__ == "__main__":
    main()