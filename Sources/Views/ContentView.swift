import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()
    #if os(iOS)
    @State private var isDarkMode = false
    #endif
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private let gridColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    // MARK: - macOS Compact Dashboard Layout

    #if os(macOS)
    private var macOSLayout: some View {
        VStack(spacing: 8) {
            compactHeaderBar
            serverGrid
            compactChartView
        }
        .padding(8)
        .frame(width: 480, height: 360)
        .frame(minWidth: 480, minHeight: 360)
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var compactHeaderBar: some View {
        HStack(spacing: 12) {
            Text("GPU Monitor")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            // Polling interval stepper
            HStack(spacing: 4) {
                Text("\(Int(viewModel.pollingInterval))s")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28, alignment: .trailing)
                Stepper("", value: $viewModel.pollingInterval, in: 1...30, step: 1)
                    .labelsHidden()
            }

            Divider()
                .frame(height: 16)

            // Total wattage
            HStack(spacing: 4) {
                Text("Total:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(viewModel.totalWattage, specifier: "%.0f")W")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(colorForWattage(viewModel.totalWattage))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColorForCard)
        .cornerRadius(6)
    }

    private var serverGrid: some View {
        Group {
            if viewModel.serverStatuses.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Connecting...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 6) {
                    ForEach(viewModel.serverStatuses) { status in
                        serverCard(status)
                    }
                }
            }
        }
    }

    private func serverCard(_ status: GPUStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)

            Text(status.hostname)
                .font(.system(.subheadline, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text("\(status.totalWattage, specifier: "%.0f")W")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(colorForWattage(status.totalWattage))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(backgroundColorForCard)
        .cornerRadius(6)
    }

    private var compactChartView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.historicalData.isEmpty {
                Text("Collecting data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(viewModel.historicalData) { dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Watts", dataPoint.watts)
                        )
                        .foregroundStyle(by: .value("Server", dataPoint.server))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartLegend(position: .bottom, spacing: 4)
                .chartXAxis(.hidden)
            }
        }
        .padding(8)
        .frame(minHeight: 120, maxHeight: .infinity)
        .background(backgroundColorForCard)
        .cornerRadius(6)
    }
    #endif

    // MARK: - iOS Layout (unchanged)

    #if os(iOS)
    private var iOSLayout: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("GPU Wattage Monitor")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                if horizontalSizeClass == .regular {
                    HStack(spacing: 20) {
                        pollingIntervalControl
                        darkModeToggle
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        pollingIntervalControl
                        darkModeToggle
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
        .preferredColorScheme(isDarkMode ? .dark : .light)
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
        .background(backgroundColorForCard)
        .cornerRadius(10)
    }

    private var darkModeToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dark Mode")
                .font(.headline)

            Toggle("", isOn: $isDarkMode)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding()
        .background(backgroundColorForCard)
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
        .background(backgroundColorForCard)
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
        .background(backgroundColorForCard)
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
        .background(backgroundColorForCard)
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
                    ForEach(viewModel.historicalData) { dataPoint in
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
        .background(backgroundColorForCard)
        .cornerRadius(10)
    }
    #endif

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

    private var backgroundColorForCard: Color {
        #if os(macOS)
        return Color(.windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
}

#Preview {
    ContentView()
}
