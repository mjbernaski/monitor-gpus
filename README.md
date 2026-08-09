# GPU Wattage Meters

Native Apple-platform GPU power monitor for two DGX Spark systems and the Vengeance 5090 workstation.

## Current Servers

The shared `servers.json` config monitors:

- `192.168.5.40:9999` - `spark-9a96`
- `192.168.5.46:9999` - `spark-96c6`
- `192.168.6.40:9999` - `VENGEANCE`

Each server is expected to expose `GET /gpu-status`.

## Build And Run

Open the checked-in Xcode project:

```bash
open GPUMonitor.xcodeproj
```

Then choose the `GPUMonitor-macOS` scheme and run it on `My Mac`.

Command-line build:

```bash
xcodebuild -project GPUMonitor.xcodeproj \
  -scheme GPUMonitor-macOS \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  build
```

CLI status check:

```bash
xcodebuild -project GPUMonitor.xcodeproj \
  -scheme gpu-cli \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  build

build/DerivedData/Build/Products/Debug/gpu-cli
```

## Project Layout

```text
Shared/
  App/GPUMonitorApp.swift
  Models/GPUStatus.swift
  Services/GPUService.swift
  Services/LoggingService.swift
  Services/SoundService.swift
  ViewModels/GPUMonitorViewModel.swift
Platforms/
  macOS/Views/ContentView.swift
  iOS/Views/ContentView.swift
  watchOS/Views/ContentView.swift
  tvOS/Views/ContentView.swift
CLI/main.swift
servers.json
project.yml
GPUMonitor.xcodeproj
```

`project.yml` is the XcodeGen source of truth if you need to regenerate the Xcode project.

## Configuration

Edit `servers.json` to add or remove GPU servers:

```json
{
  "servers": ["192.168.5.40", "192.168.5.46", "192.168.6.40"],
  "port": 9999,
  "endpoint": "/gpu-status"
}
```

## API Response

```json
{
  "hostname": "spark-9a96",
  "timestamp": "2026-07-21T19:29:40.293Z",
  "gpu_count": 1,
  "gpus": [
    {
      "gpu_id": 0,
      "power_draw_watts": 13.31,
      "memory_free_mb": null,
      "utilization_percent": 0
    }
  ]
}
```

## Troubleshooting

Direct endpoint check:

```bash
curl -s http://192.168.5.40:9999/gpu-status
curl -s http://192.168.5.46:9999/gpu-status
curl -s http://192.168.6.40:9999/gpu-status
```

If the app builds but shows no servers, first confirm those `curl` commands work from the Mac and that the Mac is on the same network as the GPU machines.
