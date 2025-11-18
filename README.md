# GPU Wattage Monitor

A macOS app that monitors GPU wattage from three servers in real-time.

## Features

- Monitors GPU wattage from three servers (192.168.5.40, 192.168.5.56, 192.168.6.40)
- Updates every 5 seconds automatically
- Displays current wattage per server
- Shows total wattage across all servers
- Line chart visualization showing wattage trends over time
- Color-coded wattage indicators (green/yellow/orange/red)

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Building and Running

### Option 1: Using Xcode

1. Open the project in Xcode:
   ```bash
   open Package.swift
   ```

2. Wait for Xcode to resolve dependencies

3. Select "My Mac" as the target

4. Press `Cmd+R` to build and run

### Option 2: Using Swift CLI

Build and run from the command line:
```bash
swift run
```

Build only:
```bash
swift build
```

## Architecture

```
Sources/
├── GPUMonitorApp.swift          # Main app entry point
├── Models/
│   └── GPUStatus.swift          # Data models
├── Services/
│   └── GPUService.swift         # Network service
├── ViewModels/
│   └── GPUMonitorViewModel.swift # State management
└── Views/
    └── ContentView.swift        # Main UI
```

## Server Configuration

The app is configured to monitor these servers:
- 192.168.5.40:9999
- 192.168.5.56:9999
- 192.168.6.40:9999

To modify the server list, edit `Sources/Services/GPUService.swift`.

## API Response Format

The app expects the `/gpu-status` endpoint to return JSON in this format:

```json
{
  "hostname": "spark-9a96",
  "timestamp": "2025-11-18T18:07:56.207Z",
  "gpu_count": 1,
  "gpus": [
    {
      "gpu_id": 0,
      "power_draw_watts": 3.7,
      "memory_free_mb": null,
      "utilization_percent": 0
    }
  ]
}
```
