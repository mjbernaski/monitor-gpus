import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()

    private let serverColors: [Color] = [.blue, .green, .orange]

    // Preferred display order — hostnames containing these prefixes are sorted first
    private let serverOrder = ["vengeance", "9a96", "96c6"]

    /// Servers sorted in preferred display order
    private var orderedStatuses: [GPUStatus] {
        viewModel.serverStatuses.sorted { a, b in
            let aIndex = serverOrder.firstIndex(where: { a.hostname.lowercased().contains($0) }) ?? serverOrder.count
            let bIndex = serverOrder.firstIndex(where: { b.hostname.lowercased().contains($0) }) ?? serverOrder.count
            return aIndex < bIndex
        }
    }

    /// Color for a given server, based on its position in orderedStatuses
    private func colorForServer(_ hostname: String) -> Color {
        if let index = orderedStatuses.firstIndex(where: { $0.hostname == hostname }) {
            return serverColors[index % serverColors.count]
        }
        return .gray
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            serverColumns
                .frame(maxHeight: .infinity)
            wattageChart
                .frame(height: 220)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("GPU MONITOR")
                .font(.system(size: 42, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            // Total wattage - the single most important number
            HStack(spacing: 16) {
                Text("TOTAL")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(viewModel.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: 64, weight: .heavy, design: .monospaced))
                    .foregroundColor(colorForWattage(viewModel.totalWattage))
            }

            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Server Columns

    private var serverColumns: some View {
        Group {
            if viewModel.serverStatuses.isEmpty {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                    Text("Connecting to servers...")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 24) {
                    ForEach(orderedStatuses) { status in
                        serverColumn(status: status, color: colorForServer(status.hostname))
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 16)
            }
        }
    }

    private func serverColumn(status: GPUStatus, color: Color) -> some View {
        VStack(spacing: 12) {
            // Server header: name + total wattage
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                    .shadow(color: .green, radius: 6)
                Text(status.hostname.uppercased())
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer()
                Text("\(status.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: 48, weight: .heavy, design: .monospaced))
                    .foregroundColor(colorForWattage(status.totalWattage))
            }

            // GPU rings
            HStack(spacing: 12) {
                ForEach(status.gpus, id: \.gpuId) { gpu in
                    gpuRingCard(gpu: gpu)
                }
            }
            .frame(maxHeight: .infinity)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(color.opacity(0.4), lineWidth: 4)
                )
        )
        .focusable()
    }

    private func gpuRingCard(gpu: GPU) -> some View {
        VStack(spacing: 8) {
            Text("GPU \(gpu.gpuId)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.5))

            // Large utilization ring that fills available space
            utilizationRing(percent: gpu.utilizationPercent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)

            if let memMb = gpu.memoryFreeMb {
                Text(formatMemory(memMb))
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private func utilizationRing(percent: Int) -> some View {
        let fraction = Double(min(percent, 100)) / 100.0
        let ringColor = colorForUtilization(percent)

        return ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 12, lineCap: .round))

            // Filled arc
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Percentage in the center
            Text("\(percent)%")
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    // MARK: - Wattage Chart (per-server only, no total line)

    private var wattageChart: some View {
        VStack(spacing: 0) {
            Divider().background(Color.gray.opacity(0.3))
            Group {
                if viewModel.historicalData.isEmpty {
                    Text("Collecting data...")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Chart {
                        ForEach(serverHistoricalData) { dataPoint in
                            LineMark(
                                x: .value("Time", dataPoint.timestamp),
                                y: .value("Watts", dataPoint.watts)
                            )
                            .foregroundStyle(by: .value("Server", dataPoint.server))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                    }
                    .chartForegroundStyleScale(domain: chartColorDomain, range: chartColorRange)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                .foregroundStyle(Color.gray.opacity(0.2))
                            AxisValueLabel()
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                .foregroundStyle(Color.gray.opacity(0.2))
                            AxisValueLabel()
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                    .chartLegend(.hidden)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Helpers

    private var chartColorDomain: [String] {
        orderedStatuses.map { $0.hostname }
    }

    private var chartColorRange: [Color] {
        orderedStatuses.map { colorForServer($0.hostname) }
    }

    /// Historical data excluding the "Total" line
    private var serverHistoricalData: [WattageDataPoint] {
        viewModel.historicalData.filter { $0.watts.isFinite && $0.server != "Total" }
    }

    private func colorForWattage(_ watts: Double) -> Color {
        switch watts {
        case ..<50: return .green
        case 50..<100: return .yellow
        case 100..<200: return .orange
        default: return .red
        }
    }

    private func colorForUtilization(_ percent: Int) -> Color {
        switch percent {
        case ..<25: return .green
        case 25..<50: return .blue
        case 50..<75: return .yellow
        case 75..<90: return .orange
        default: return .red
        }
    }

    private func formatMemory(_ mb: Int) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB free", Double(mb) / 1024.0)
        }
        return "\(mb) MB free"
    }
}

#Preview {
    ContentView()
}
