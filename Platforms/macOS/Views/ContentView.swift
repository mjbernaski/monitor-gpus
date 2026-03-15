import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()

    private let gridColumns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        VStack(spacing: 4) {
            compactHeaderBar
            serverGrid
            compactChartView
        }
        .padding(6)
        .frame(width: 400, height: 300)
        .frame(minWidth: 400, minHeight: 300)
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var compactHeaderBar: some View {
        HStack(spacing: 8) {
            Text("GPU Monitor")
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            // Polling interval stepper
            HStack(spacing: 2) {
                Text("\(Int(viewModel.pollingInterval))s")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 22, alignment: .trailing)
                Stepper("", value: $viewModel.pollingInterval, in: 1...30, step: 1)
                    .labelsHidden()
                    .scaleEffect(0.85)
            }

            Divider()
                .frame(height: 12)

            // Total wattage
            HStack(spacing: 3) {
                Text("Total:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("\(viewModel.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(colorForWattage(viewModel.totalWattage))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(5)
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
                LazyVGrid(columns: gridColumns, spacing: 4) {
                    ForEach(viewModel.serverStatuses) { status in
                        serverCard(status)
                    }
                }
            }
        }
    }

    private func serverCard(_ status: GPUStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colorForServer(status.hostname))
                .frame(width: 5, height: 5)

            Text(status.hostname)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Text("\(status.totalWattage, specifier: "%.0f")W")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(colorForWattage(status.totalWattage))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(5)
    }

    private var compactChartView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if viewModel.historicalData.isEmpty {
                Text("Collecting data...")
                    .font(.system(size: 10))
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
                .chartForegroundStyleScale(domain: chartServers, range: chartColors)
                .chartLegend(position: .bottom, spacing: 2)
                .chartXAxis(.hidden)
            }
        }
        .padding(6)
        .frame(minHeight: 100, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(5)
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

    private let serverColors: [Color] = [.blue, .green, .orange, .cyan, .pink, .yellow]

    private func colorForServer(_ name: String) -> Color {
        if name == "Total" { return .purple }
        let sorted = viewModel.serverStatuses.map(\.hostname).sorted()
        if let index = sorted.firstIndex(of: name) {
            return serverColors[index % serverColors.count]
        }
        return .gray
    }

    private var safeHistoricalData: [WattageDataPoint] {
        viewModel.historicalData.filter { $0.watts.isFinite }
    }

    private var chartServers: [String] {
        var serverSet = Set(viewModel.historicalData.map(\.server))
        serverSet.remove("Total")
        var servers = serverSet.sorted()
        servers.append("Total")
        return servers
    }

    private var chartColors: [Color] {
        return chartServers.map { colorForServer($0) }
    }
}

#Preview {
    ContentView()
}
