# GPU Wattage Meters - Platform Guide

This repository is a single Xcode project with shared monitoring code and platform-specific SwiftUI views.

## Schemes

- `GPUMonitor-macOS` - native macOS app
- `GPUMonitor-iOS` - iPhone/iPad app
- `GPUMonitor-watchOS` - watchOS app
- `GPUMonitor-tvOS` - tvOS dashboard
- `GPUMonitorWidgetApp` - macOS widget host app
- `GPUMonitorWidgetExtension` - macOS widget extension
- `gpu-cli` - command-line status checker

## macOS

Run from Xcode:

```bash
open GPUMonitor.xcodeproj
```

Select `GPUMonitor-macOS`, destination `My Mac`, then run.

Build from the command line:

```bash
xcodebuild -project GPUMonitor.xcodeproj \
  -scheme GPUMonitor-macOS \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  build
```

## CLI

The CLI is useful for verifying server connectivity without launching the app:

```bash
xcodebuild -project GPUMonitor.xcodeproj \
  -scheme gpu-cli \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  build

build/DerivedData/Build/Products/Debug/gpu-cli
```

## Shared Configuration

All app targets use `servers.json`:

```json
{
  "servers": ["192.168.5.40", "192.168.5.46", "192.168.6.40"],
  "port": 9999,
  "endpoint": "/gpu-status"
}
```

Current expected hosts:

- `spark-9a96`
- `spark-96c6`
- `VENGEANCE`

## Code Sharing

Shared code lives in `Shared/`:

- `Models/` - JSON models and chart data points
- `Services/` - network fetching, logging, and sound
- `ViewModels/` - polling and app state
- `App/` - shared SwiftUI app entry point

Platform views live under `Platforms/<platform>/Views/ContentView.swift`.

## Notes

- The app targets allow local HTTP through `NSAppTransportSecurity` in their platform plists.
- Logs for macOS and iOS are written under `GPUMonitorLogs` in the user/app Documents directory.
- `project.yml` is the XcodeGen source file if the checked-in `GPUMonitor.xcodeproj` needs to be regenerated.
