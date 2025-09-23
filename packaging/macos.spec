# -*- mode: python ; coding: utf-8 -*-

import os
from PyInstaller.utils.hooks import collect_submodules, collect_all
from PyInstaller.building.build_main import Analysis, PYZ, EXE, COLLECT, BUNDLE
from PyInstaller.building.datastruct import Tree

block_cipher = None

project_root = os.path.abspath(os.path.join(SPECPATH, '..'))

# Collect all google.protobuf modules
protobuf_datas, protobuf_binaries, protobuf_hiddenimports = collect_all('google.protobuf')

# Data files to include in the app bundle
datas = protobuf_datas
datas += [(os.path.join(project_root, 'docs', 'setup_blackhole.md'), 'setup_blackhole.md')] if os.path.exists(os.path.join(project_root, 'docs', 'setup_blackhole.md')) else []
# Include all necessary Python modules from backend directory
datas += [(os.path.join(project_root, 'backend', 'config.py'), '.')]
datas += [(os.path.join(project_root, 'backend', 'logger.py'), '.')]
datas += [(os.path.join(project_root, 'backend', 'preferences.py'), '.')]
datas += [(os.path.join(project_root, 'backend', 'realtime_simple.py'), '.')]
datas += [(os.path.join(project_root, 'backend', 'health_monitor.py'), '.')]
# Include app_secrets.json if it exists
datas += [(os.path.join(project_root, 'app_secrets.json'), '.')] if os.path.exists(os.path.join(project_root, 'app_secrets.json')) else []

# Trees: recursive copy into bundle resources
trees = []
# AST SDK 
trees.append(Tree(os.path.join(project_root, 'ast_python', 'python_protogen'), prefix='ast_python/python_protogen'))
trees.append(Tree(os.path.join(project_root, 'resources'), prefix='resources'))

hiddenimports = [
    'websockets', 'sounddevice', 'rumps', 'AppKit', 'Foundation',
    'numpy', 'colorlog', 'keyring', 'dotenv', 'python-dotenv',
    'pyobjc', 'objc', 'PyObjCTools', 'threading', 'asyncio',
    'cffi', '_cffi_backend', 'AVFoundation', 'CoreMedia'
] + protobuf_hiddenimports

a = Analysis(
    [os.path.join(project_root, 'backend', 'app_menu.py')],
    pathex=[project_root],
    binaries=protobuf_binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='BabelAI',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=True,
    target_arch=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    *trees,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='BabelAI'
)

# macOS app bundle with custom Info.plist
bundle = BUNDLE(
    coll,
    name='BabelAI.app',
    icon=os.path.join(SPECPATH, 'BabelAI.icns'),
    bundle_identifier='com.babelai.translator',
    info_plist=os.path.join(SPECPATH, 'Info.plist'),
)

