import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("GPU Wattage Monitor")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                if horizontalSizeClass == .regular {
                    HStack(spacing: 20) {
                        pollingIntervalControl
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        pollingIntervalControl
                    }
                    .padding(.horizontal)
                }

                serverStatusView
                    .padding(.horizontal)

                totalWattageView
                    .padding(.horizontal)

                chartView
                    .frame(height: 300)
                    .padding()

                logFileInfo
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var logFileInfo: some View {
        HStack {
            Text("Log file:")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Share Logs") {
                Task {
                    let logURL = await LoggingService.shared.getLogFileURL()
                    let activityVC = UIActivityViewController(activityItems: [logURL], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        if let popover = activityVC.popoverPresentationController {
                            popover.sourceView = rootViewController.view
                            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                            popover.permittedArrowDirections = []
                        }
                        rootViewController.present(activityVC, animated: true)
                    }
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    private var pollingIntervalControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Polling Interval:")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.pollingInterval, specifier: "%.0f") second\(viewModel.pollingInterval == 1 ? "" : "s")")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Slider(value: $viewModel.pollingInterval, in: 1...30, step: 1)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    private var serverStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Server Status")
                .font(.headline)

            if viewModel.serverStatuses.isEmpty {
                Text("Loading...")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.serverStatuses) { status in
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)

                        Text(status.hostname)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if let ipAddress = status.ipAddress {
                            Text(ipAddress)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Text("\(status.totalWattage, specifier: "%.1f") W")
                            .font(.system(.body, design: .monospaced))
                            .bold()
                            .foregroundColor(colorForWattage(status.totalWattage))

                        Spacer()

                        Text("\(status.gpuCount) GPU\(status.gpuCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    private var totalWattageView: some View {
        HStack {
            Text("Total Wattage:")
                .font(.title2)
                .bold()

            Spacer()

            Text("\(viewModel.totalWattage, specifier: "%.1f") W")
                .font(.system(.title, design: .monospaced))
                .bold()
                .foregroundColor(colorForWattage(viewModel.totalWattage))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    private var chartView: some View {
        VStack(alignment: .leading) {
            Text("Wattage Over Time")
                .font(.headline)
                .padding(.bottom, 8)

            if viewModel.historicalData.isEmpty {
                Text("Collecting data...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(safeHistoricalData) { dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Watts", dataPoint.watts)
                        )
                        .foregroundStyle(by: .value("Server", dataPoint.server))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxisLabel("Watts")
                .chartXAxisLabel("Time")
                .chartLegend(position: .bottom)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    // MARK: - Helpers

    private func colorForWattage(_ watts: Double) -> Color {
        switch watts {
        case ..<50:
            return .green
        case 50..<100:
            return .yellow
        case 100..<200:
            return .orange
        default:
            return .red
        }
    }

    private var safeHistoricalData: [WattageDataPoint] {
        viewModel.historicalData.filter { $0.watts.isFinite }
    }
}

#Preview {
    ContentView()
}
