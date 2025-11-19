# GPU Monitor for iOS/iPadOS

This directory contains the iOS/iPadOS version of the GPU Wattage Monitor app.

## Quick Setup (Automated)

The fastest way to get started:

```bash
cd GPUMonitorIOS

# Install xcodegen if you don't have it
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open the project
open GPUMonitorIOS.xcodeproj
```

Then just build and run in Xcode!

## Manual Setup in Xcode

If you prefer not to use xcodegen or don't have Homebrew:

1. Open Xcode
2. Click "Create a new Xcode project"
3. Select "iOS" → "App" template
4. Configure the project:
   - Product Name: "GPUMonitorIOS"
   - Interface: "SwiftUI"
   - Lifecycle: "SwiftUI App"
   - Minimum iOS version: 17.0
5. Save in this `GPUMonitorIOS` directory

6. Replace default files:
   - Delete `ContentView.swift` and `GPUMonitorIOSApp.swift` that Xcode creates
   - Drag the entire `Sources` folder into your Xcode project
   - Make sure "Copy items if needed" is **unchecked** (files are already here)
   - Ensure all files are added to your app target

7. Add configuration:
   - Drag `servers.json` into your Xcode project
   - Make sure it's added to "Copy Bundle Resources" in Build Phases
   - Replace the default Info.plist with the one in this directory

8. Build and run on iOS Simulator or device!

## Features on iOS/iPadOS

- Real-time GPU wattage monitoring from remote servers
- Live charts showing power consumption over time
- Adjustable polling interval (1-30 seconds)
- Dark mode toggle
- Responsive layout for iPhone and iPad
- Share logs functionality (tap "Share Logs" button)
- All network requests work the same as macOS version

## Configuration

Edit `servers.json` to configure your GPU servers:

```json
{
  "servers": ["192.168.5.40", "192.168.5.46", "192.168.6.40"],
  "port": 9999,
  "endpoint": "/gpu-status"
}
```

## System Requirements

- iOS 17.0+ or iPadOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Differences from macOS Version

- Uses iOS-style share sheet instead of Finder integration for logs
- Responsive layout adapts to iPhone and iPad screen sizes
- Touch-optimized controls
- Background color uses iOS system colors

## Notes

- The app requires network access to fetch GPU status from your servers
- Make sure your iOS device is on the same network as your GPU servers
- Logs are saved to the app's Documents directory
