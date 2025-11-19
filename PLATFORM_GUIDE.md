# GPU Wattage Monitor - Platform Guide

This repository contains GPU monitoring applications for both macOS and iOS/iPadOS.

## 📦 What's Included

- **macOS Version**: Swift Package in the root directory
- **iOS/iPadOS Version**: Xcode project in `GPUMonitorIOS/` directory

## 🖥️ macOS Version

### Running on macOS

```bash
# Build and run
swift build -c release
.build/release/GPUMonitor

# Or run directly
swift run
```

### Features
- Native macOS window with hidden title bar
- Fixed window size optimized for desktop
- Finder integration for log files
- Menu bar controls

## 📱 iOS/iPadOS Version

### Quick Setup

The easiest way to get started with the iOS version:

```bash
cd GPUMonitorIOS
./setup.sh
```

This script will:
1. Check for/install xcodegen
2. Generate the Xcode project
3. Open it in Xcode

Alternatively, see `GPUMonitorIOS/README.md` for manual setup instructions.

### Features
- Responsive layout for iPhone and iPad
- Portrait and landscape support
- iOS share sheet for log files
- Touch-optimized controls
- Adaptive UI based on device size

## 🔧 Shared Features

Both versions include:
- Real-time GPU wattage monitoring from remote servers
- Live charts showing power consumption over time
- Multiple server monitoring
- Configurable polling interval (1-30 seconds)
- Dark mode support
- CSV logging to disk
- Server status indicators

## ⚙️ Configuration

Both versions use `servers.json` for configuration:

```json
{
  "servers": ["192.168.5.40", "192.168.5.46", "192.168.6.40"],
  "port": 9999,
  "endpoint": "/gpu-status"
}
```

Edit this file to add/remove GPU servers or change the endpoint.

## 📊 Server Requirements

Your GPU servers need to provide a JSON endpoint with this format:

```json
{
  "hostname": "server1",
  "timestamp": "2025-01-01T12:00:00Z",
  "gpu_count": 2,
  "gpus": [
    {
      "gpu_id": 0,
      "power_draw_watts": 150.5,
      "memory_free_mb": 8192,
      "utilization_percent": 75
    }
  ]
}
```

## 🛠️ Development

### Requirements
- macOS: Swift 5.9+, macOS 14+
- iOS: Xcode 15+, iOS 17+

### Project Structure
```
.
├── Sources/
│   ├── GPUMonitorApp.swift      # App entry point (cross-platform)
│   ├── Models/                  # Data models
│   ├── Services/                # Network & logging services
│   ├── ViewModels/              # Business logic
│   └── Views/                   # SwiftUI views
├── GPUMonitorIOS/               # iOS-specific project
│   ├── setup.sh                 # Automated setup script
│   ├── project.yml              # XcodeGen configuration
│   └── README.md                # iOS-specific instructions
└── servers.json                 # Server configuration
```

## 🔄 Code Sharing

The codebase is designed to be cross-platform:
- Platform-specific code is wrapped in `#if os(macOS)` / `#else` blocks
- Networking and business logic are fully shared
- UI adapts automatically to each platform's conventions

## 📝 Notes

### Network Access
- Both apps require network access to your GPU servers
- Make sure your device is on the same network as the servers
- For iOS, the Info.plist includes `NSAllowsArbitraryLoads` to allow HTTP connections

### Logs
- **macOS**: Logs saved to `~/Documents/GPUMonitorLogs/`
- **iOS**: Logs saved to app's Documents directory (accessible via Files app or iTunes)

### Background Monitoring
- Currently, both apps only monitor while in the foreground
- Background monitoring could be added with appropriate permissions

## 🐛 Troubleshooting

### Can't connect to servers
- Verify servers are accessible: `ping <server-ip>`
- Check firewall settings
- Ensure port 9999 (or your custom port) is open

### iOS build errors
- Make sure Xcode 15+ is installed
- Verify iOS deployment target is set to 17.0+
- Clean build folder: Cmd+Shift+K in Xcode

### macOS build errors
- Ensure you're running macOS 14+
- Update Xcode Command Line Tools: `xcode-select --install`

## 📄 License

Copyright © 2025. All rights reserved.
