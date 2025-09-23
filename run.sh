#!/bin/bash
# S2S 一键启动脚本

echo "================================"
echo "S2S - 实时语音翻译系统"
echo "版本: $(cat VERSION 2>/dev/null || echo '1.0.0')"
echo "================================"
echo ""

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到Python3"
    echo "请安装Python 3.8或更高版本"
    exit 1
fi

# 检查并创建虚拟环境
if [ ! -d "venv" ]; then
    echo "创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
echo "激活虚拟环境..."
source venv/bin/activate

# 安装/更新依赖
echo "检查依赖..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# 选择运行模式
echo ""
echo "请选择运行模式："
echo "1) 终端模式 - 在终端中运行，查看日志"
echo "2) 菜单栏应用 - macOS菜单栏应用"
echo "3) 测试模式 - 运行健壮性测试"
echo ""
read -p "请输入选项 (1-3): " choice

case $choice in
    1)
        echo ""
        echo "启动终端模式..."
        python backend/start.py
        ;;
    2)
        echo ""
        echo "启动菜单栏应用..."
        python backend/app_menu.py
        ;;
    3)
        echo ""
        echo "运行健壮性测试..."
        python test_robustness.py
        ;;
    *)
        echo "无效选项，默认启动终端模式..."
        python backend/start.py
        ;;
esac