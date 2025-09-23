#!/usr/bin/env python3
"""
一键启动脚本 - 自动检查环境并运行实时翻译系统
"""
import subprocess
import sys
import os
from pathlib import Path
from logger import logger, set_level

def check_python_version():
    """检查Python版本"""
    if sys.version_info < (3, 8):
        logger.error("需要 Python 3.8 或更高版本")
        logger.error(f"当前版本: {sys.version}")
        sys.exit(1)
    logger.info(f"Python版本: {sys.version.split()[0]}")

def check_env_file():
    """检查.env配置文件（放宽：缺失不再阻塞）"""
    env_file = Path(".env")
    if env_file.exists():
        logger.info("检测到 .env，将加载其中配置")
    else:
        logger.info("未找到 .env，将尝试从 Keychain / app_secrets.json 读取凭证")

def install_dependencies():
    """安装依赖包"""
    logger.info("检查依赖包...")
    
    # 检查是否存在虚拟环境
    venv_path = Path("venv")
    if venv_path.exists():
        logger.info("使用已存在的虚拟环境")
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
        logger.info("依赖包已安装")
    except ImportError:
        logger.info("正在安装依赖包...")
        result = subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"], 
                              capture_output=True, text=True)
        if result.returncode != 0:
            logger.error("依赖安装失败")
            logger.error(result.stderr)
            sys.exit(1)
        logger.info("依赖包安装完成")
    
    return sys.executable

def check_audio_devices():
    """检查音频设备"""
    logger.info("检查音频设备...")
    try:
        import sounddevice as sd
        devices = sd.query_devices()
        input_devices = [d for d in devices if d['max_input_channels'] > 0]
        
        if not input_devices:
            logger.error("未找到可用的麦克风设备")
            logger.info("请确保已连接麦克风")
            sys.exit(1)
        
        default_input = sd.default.device[0]
        if default_input is not None and default_input < len(devices):
            logger.info(f"默认麦克风: {devices[default_input]['name']}")
        else:
            logger.info(f"找到 {len(input_devices)} 个麦克风设备")
    
    except Exception as e:
        logger.warning(f"无法检查音频设备: {e}")
        logger.info("继续运行，但可能遇到音频问题")

def run_translator(python_exe):
    """运行翻译程序"""
    logger.info("="*50)
    logger.info("启动实时语音翻译系统")
    logger.info("功能: 中文语音 → 英文语音, 实时翻译, 按 Ctrl+C 退出")
    logger.info("="*50)
    
    try:
        subprocess.run([python_exe, "realtime_simple.py"])
    except KeyboardInterrupt:
        logger.info("感谢使用，再见！")
    except Exception as e:
        logger.error(f"运行出错: {e}")
        sys.exit(1)

def main():
    """主函数"""
    # 允许通过环境变量调整日志级别
    lvl = os.getenv('LOG_LEVEL')
    if lvl:
        set_level(lvl)

    logger.info("实时语音翻译系统 - 启动检查")
    logger.info("="*50)
    
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
