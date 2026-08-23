# CI/CD and TestFlight

## Continuous integration

`.github/workflows/ci.yml` regenerates the Xcode project and builds every app and CLI scheme without signing. It runs for pull requests, pushes to `main`, and manual dispatches.

## TestFlight deployment

`.github/workflows/testflight.yml` archives and uploads the two products currently registered in App Store Connect:

- `GPUMonitor-iOS`, including its embedded watchOS app
- `GPUMonitor-tvOS`

The workflow assigns a monotonically increasing build number based on the GitHub Actions run number.

Configure these GitHub Actions repository secrets before running the workflow:

- `ASC_KEY_ID`: App Store Connect API key ID
- `ASC_ISSUER_ID`: App Store Connect API issuer ID
- `ASC_PRIVATE_KEY`: complete contents of the corresponding `.p8` private key

The API key needs sufficient App Store Connect access to manage builds and signing assets.

The standalone macOS app (`com.gpumonitor.macos`) and widget host (`com.gpumonitor.widget`) are built by CI but are not uploaded. App Store Connect app records for those bundle identifiers must be created before adding them to the TestFlight deployment matrix.
