# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

### Unified Xcode Project (XcodeGen)
```bash
xcodegen generate             # Generate GPUMonitor.xcodeproj from project.yml
open GPUMonitor.xcodeproj     # Open in Xcode (select scheme for desired platform)
```

### Build Individual Targets
```bash
xcodebuild -scheme GPUMonitor-macOS build
xcodebuild -scheme GPUMonitor-iOS -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme GPUMonitor-watchOS -destination 'generic/platform=watchOS Simulator' build
xcodebuild -scheme GPUMonitor-tvOS -destination 'generic/platform=tvOS Simulator' build
xcodebuild -scheme GPUMonitorWidgetApp build
xcodebuild -scheme gpu-cli build
```

## Architecture

This is a cross-platform SwiftUI GPU wattage monitoring app supporting macOS 14+, iOS 17+, watchOS 10+, and tvOS 17+. All platforms are managed through a single `project.yml` at the repo root.

### Code Organization

```
Shared/              # Code included by all 4 app targets
  App/               # GPUMonitorApp.swift (@main entry point)
  Models/            # GPUStatus.swift (data models)
  Services/          # GPUService.swift, LoggingService.swift
  ViewModels/        # GPUMonitorViewModel.swift (consolidated with #if os())

Platforms/           # Per-platform UI (ContentView.swift) and config
  macOS/Views/       # macOS compact dashboard
  iOS/Views/         # iOS scrollable layout
  watchOS/Views/     # watchOS tiny layout
  tvOS/Views/        # tvOS NOC dashboard

Widget/              # macOS widget (self-contained, does NOT use Shared/)
  App/               # Widget host app
  Extension/         # WidgetKit extension with its own GPUService/GPUStatus

CLI/                 # Self-contained CLI tool (main.swift with embedded models)
```

### MVVM Pattern with Swift Concurrency

**Data Flow:**
1. `GPUMonitorViewModel` starts a timer-based polling loop
2. `GPUService` (actor) fetches all servers concurrently via `TaskGroup`
3. JSON responses decoded into `GPUStatus` models
4. `LoggingService` (actor) writes CSV logs (macOS/iOS only, not watchOS/tvOS)
5. Historical data appended and capped at `maxDataPoints`
6. Published properties trigger SwiftUI view updates

**Key Services:**
- `GPUService.shared` - Singleton actor for thread-safe HTTP fetching
- `LoggingService.shared` - Singleton actor for CSV logging (not on watchOS/tvOS)

### Platform-Specific Differences

Platform conditionals in shared code use `#if os(macOS)`, `#if os(iOS)`, `#if os(watchOS)`, `#if os(tvOS)`.

| Aspect | macOS/iOS | watchOS | tvOS |
|--------|-----------|---------|------|
| Default polling | 1 second | 5 seconds | 2 seconds |
| Max data points | 60 | 30 | 120 |
| CSV logging | Yes | No | No |
| Total wattage in chart | Yes | No | Yes |
| Polling control | Stepper/Slider | N/A | +/- Buttons |

### project.yml Targets

| Target | Type | Platform | Sources |
|--------|------|----------|---------|
| GPUMonitor-macOS | application | macOS | Shared/, Platforms/macOS/Views/ |
| GPUMonitor-iOS | application | iOS | Shared/, Platforms/iOS/Views/ |
| GPUMonitor-watchOS | application | watchOS | Shared/, Platforms/watchOS/Views/ |
| GPUMonitor-tvOS | application | tvOS | Shared/, Platforms/tvOS/Views/ |
| GPUMonitorWidgetApp | application | macOS | Widget/App/ |
| GPUMonitorWidgetExtension | extensionkit-extension | macOS | Widget/Extension/ |
| gpu-cli | tool | macOS | CLI/ |

### Configuration

Server configuration in `servers.json`:
```json
{
  "servers": ["192.168.5.40", "192.168.5.46", "192.168.6.40"],
  "port": 9999,
  "endpoint": "/gpu-status"
}
```

Expected API response format:
```json
{
  "hostname": "server-name",
  "timestamp": "2025-01-01T12:00:00Z",
  "gpu_count": 1,
  "gpus": [{"gpu_id": 0, "power_draw_watts": 150.5, "memory_free_mb": 8192, "utilization_percent": 75}]
}
```

## Notes

- Shared code is consolidated with `#if os()` conditionals; only ContentView stays per-platform
- Widget and CLI targets are self-contained (do NOT link Shared/)
- All platforms require `NSAllowsArbitraryLoads` for HTTP connections (set in each Info.plist)
- Apps only monitor while in foreground (no background support)
- After editing `project.yml`, re-run `xcodegen generate` to regenerate the .xcodeproj
- No automated tests exist in this codebase
