# Babel AI - Native macOS Application

Real-time speech translation application built with Swift and SwiftUI.

## 🚀 Quick Start

### One-Command Setup

```bash
chmod +x build.sh
./build.sh
```

This will:
1. Install all dependencies (protobuf, swift-protobuf, XcodeGen)
2. Generate Swift protobuf code
3. Create Xcode project
4. Open Xcode for you

### Manual Setup

If you prefer manual setup:

```bash
# Install dependencies
brew install protobuf swift-protobuf xcodegen

# Generate protobuf files
cd Proto
protoc --swift_out=. --proto_path=. \
    common/events.proto \
    common/rpcmeta.proto \
    products/understanding/base/au_base.proto \
    products/understanding/ast/ast_service.proto

# Generate Xcode project
cd ..
xcodegen generate

# Open project
open BabelAI.xcodeproj
```

## 📋 Requirements

- macOS 13.0+
- Xcode 14.0+
- Homebrew (for dependencies)
- API credentials (in `.env` file)

## 🔧 Configuration

The app reads configuration from `../.env` file automatically:

```env
# API Authentication
API_APP_KEY=your_app_key
API_ACCESS_KEY=your_access_key
API_RESOURCE_ID=volc.service_type.10053

# WebSocket Configuration
WS_URL=wss://openspeech.bytedance.com/api/v4/ast/v2/translate

# Audio Settings
SOURCE_LANGUAGE=zh
TARGET_LANGUAGE=en
```

## 🏗️ Project Structure

```
BabelAI/
├── App/                    # Application entry point
│   ├── BabelAIApp.swift   # Main app
│   └── Info.plist         # App configuration
├── Views/                  # SwiftUI views
│   ├── MainView.swift     # Main window
│   ├── SubtitleView.swift # Subtitle window
│   └── SettingsView.swift # Settings interface
├── Services/               # Core services
│   ├── AudioManager.swift # Audio capture (16kHz)
│   ├── AudioPlayer.swift  # Audio playback (48kHz)
│   ├── TranslationService.swift # WebSocket & protocol
│   └── WireCodec.swift    # Protobuf encoding/decoding
├── Models/                 # Data models
│   ├── Config.swift       # Configuration & Keychain
│   ├── Preferences.swift  # User preferences
│   └── TranscriptModel.swift # Subtitle data
├── Proto/                  # Protocol buffers
│   └── *.proto + generated Swift files
├── project.yml            # XcodeGen configuration
└── build.sh               # Build script
```

## 🎯 Features

### Completed (Phase 1 & 2)
- ✅ Native macOS application with SwiftUI
- ✅ Real-time audio capture (AVAudioEngine)
- ✅ WebSocket communication with protobuf
- ✅ 80ms precise audio chunking
- ✅ 48kHz audio playback with fade-out
- ✅ Automatic .env configuration loading
- ✅ Native microphone permission handling
- ✅ Health monitoring and metrics
- ✅ Exponential backoff reconnection
- ✅ Subtitle window display

### Technical Implementation
- **Audio Pipeline**: 16kHz mono capture → 80ms chunks → WebSocket → 48kHz playback
- **Protocol**: Binary protobuf over WebSocket
- **Timing**: Precise 80ms pacing with drift correction
- **Queue**: Maximum 300 chunks, oldest dropped when full
- **Heartbeat**: 30-second ping/pong for connection health

## 🚦 Running the App

1. **Build**: Run `./build.sh` or use Xcode
2. **First Launch**: Grant microphone permission when prompted
3. **Start Translation**: Click "Start" button in main window
4. **View Subtitles**: Subtitle window appears automatically
5. **Stop**: Click "Stop" to end translation

## 🔍 Troubleshooting

### Microphone Permission
- Permission dialog appears when clicking "Start"
- If denied, go to System Settings → Privacy → Microphone

### API Connection
- Check `.env` file exists with valid credentials
- Verify network connection
- Check console logs for detailed errors

### Build Issues
- Run `./build.sh` to reinstall dependencies
- Clean build folder in Xcode (Shift+Cmd+K)
- Regenerate project with `xcodegen generate`

## 📝 Development Notes

### Code Signing
- Uses automatic signing with `-` (ad-hoc)
- No hardened runtime for easier development
- For App Store, update signing settings in project.yml

### Dependencies
- SwiftProtobuf: Binary protocol serialization
- No other external dependencies (pure Swift/Apple frameworks)

### Key Files
- `WireCodec.swift`: Complete protobuf implementation
- `Config.swift`: Automatic .env loading with Keychain fallback
- `AudioManager.swift`: macOS-compatible audio capture
- `TranslationService.swift`: WebSocket with 80ms pacing

## 🎉 Status

**Phase 1 & 2: COMPLETE** ✅

The application is now fully functional with:
- Complete protobuf integration
- Automatic configuration from .env
- Real-time audio translation
- Professional audio quality
- Native macOS experience

Ready for Phase 3 (UI enhancements) and Phase 4 (App Store preparation).