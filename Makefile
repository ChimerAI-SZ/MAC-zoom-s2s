# S2S Makefile
# 实时语音翻译系统构建脚本

.PHONY: help install run test clean build app verify menu

# 默认目标
help:
	@echo "S2S - 实时语音翻译系统"
	@echo "======================"
	@echo "可用命令："
	@echo "  make install    - 安装依赖"
	@echo "  make run        - 运行翻译系统（终端模式）"
	@echo "  make menu       - 运行菜单栏应用"
	@echo "  make test       - 运行健壮性测试"
	@echo "  make verify     - 验证改进"
	@echo "  make build      - 构建macOS应用"
	@echo "  make dmg        - 构建DMG镜像（拖拽安装）"
	@echo "  make pkg        - 构建PKG安装包"
	@echo "  make clean      - 清理生成文件"
	@echo "  make app        - 构建并运行应用"

# 安装依赖
install:
	@echo "安装依赖包..."
	pip install -r requirements.txt
	@echo "依赖安装完成"

# 运行终端模式
run:
	@echo "启动实时翻译系统..."
	python start.py

# 运行菜单栏应用
menu:
	@echo "启动菜单栏应用..."
	python app_menu.py

# 运行测试
test:
	@echo "运行健壮性测试..."
	python tests/test_robustness.py

# 验证改进
verify:
	@echo "验证系统改进..."
	python tests/verify_improvements.py

# 构建macOS应用
build:
	@echo "构建macOS应用..."
	cd packaging && pyinstaller --clean --noconfirm macos.spec
	@echo "应用构建完成: packaging/dist/S2S.app"

# 构建DMG镜像
dmg: build
	@echo "构建DMG镜像..."
	cd packaging && bash build_dmg.sh
	@echo "DMG构建完成: packaging/dist/S2S-*.dmg"

# 构建PKG安装包
pkg: build
	@echo "构建PKG安装包..."
	cd packaging && bash build_pkg.sh
	@echo "PKG构建完成: packaging/dist/S2S-*.pkg"

# 清理生成文件
clean:
	@echo "清理生成文件..."
	rm -rf build/ __pycache__/ *.pyc *.pyo
	rm -rf packaging/build packaging/dist
	rm -rf archive/build_temp archive/packaging_temp
	@echo "清理完成"

# 构建并运行应用
app: build
	@echo "启动S2S.app..."
	open packaging/dist/S2S.app

# 查看版本
version:
	@echo "S2S 版本: $(shell cat VERSION)"

# 运行快速启动脚本
quick:
	@if [ -f quickstart.sh ]; then \
		bash quickstart.sh; \
	else \
		echo "quickstart.sh 不存在"; \
	fi

# 检查环境
check:
	@echo "检查环境配置..."
	@python -c "import sys; print(f'Python: {sys.version}')"
	@python -c "import sounddevice as sd; print(f'音频设备: {len(sd.query_devices())}个')"
	@python -c "from config import Config; c=Config.from_env(); print('API配置: OK' if c.api.app_key else 'API配置: 缺失')"

