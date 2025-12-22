# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

### macOS (Swift Package Manager)
```bash
swift run                    # Build and run
swift build                  # Build only
swift build -c release       # Build release version
open Package.swift           # Open in Xcode
```

### iOS/iPadOS (XcodeGen)
```bash
cd GPUMonitorIOS
./setup.sh                   # Automated setup (installs xcodegen, generates project, opens Xcode)

# Or manually:
brew install xcodegen
xcodegen generate
open GPUMonitorIOS.xcodeproj
```

### watchOS (XcodeGen)
```bash
cd GPUMonitorWatch
xcodegen generate
open GPUMonitorWatch.xcodeproj
```

## Architecture

This is a cross-platform SwiftUI GPU wattage monitoring app supporting macOS 14+, iOS 17+, and watchOS 10+.

### Code Organization

Each platform has its own `Sources/` directory with duplicated code:
- `Sources/` - macOS (Swift Package Manager)
- `GPUMonitorIOS/Sources/` - iOS/iPadOS (XcodeGen project)
- `GPUMonitorWatch/Sources/` - watchOS (XcodeGen project)

### MVVM Pattern with Swift Concurrency

**Data Flow:**
1. `GPUMonitorViewModel` starts a timer-based polling loop
2. `GPUService` (actor) fetches all servers concurrently via `TaskGroup`
3. JSON responses decoded into `GPUStatus` models
4. `LoggingService` (actor) writes CSV logs (macOS/iOS only, not watchOS)
5. Historical data appended and capped at `maxDataPoints`
6. Published properties trigger SwiftUI view updates

**Key Services:**
- `GPUService.shared` - Singleton actor for thread-safe HTTP fetching
- `LoggingService.shared` - Singleton actor for CSV logging (not on watchOS)

### Platform-Specific Differences

| Aspect | macOS/iOS | watchOS |
|--------|-----------|---------|
| Default polling | 1 second | 5 seconds |
| Max data points | 60 | 30 |
| CSV logging | Yes | No |
| Total wattage in chart | Yes | No |

Platform conditionals use `#if os(macOS)`, `#if os(iOS)`, `#if os(watchOS)`.

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

- Code is duplicated across platforms rather than shared via a framework
- iOS requires `NSAllowsArbitraryLoads` in Info.plist for HTTP connections
- Apps only monitor while in foreground (no background support)
- No automated tests exist in this codebase
