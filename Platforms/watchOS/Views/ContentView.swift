import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()

    private let serverOrder = ["vengeance", "9a96", "96c6"]

    private var orderedStatuses: [GPUStatus] {
        viewModel.serverStatuses.sorted { a, b in
            let aIndex = serverOrder.firstIndex(where: { a.hostname.lowercased().contains($0) }) ?? serverOrder.count
            let bIndex = serverOrder.firstIndex(where: { b.hostname.lowercased().contains($0) }) ?? serverOrder.count
            return aIndex < bIndex
        }
    }

    var body: some View {
        Group {
            if viewModel.serverStatuses.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Connecting…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                TabView {
                    overviewPage
                    ForEach(orderedStatuses) { status in
                        serverPage(status)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var overviewPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("ALL SYSTEMS")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)

                Text("\(viewModel.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(colorForWattage(viewModel.totalWattage))
                    .contentTransition(.numericText())

                if viewModel.totalMemoryCapacityGb > 0 {
                    Text("\(viewModel.totalMemoryCapacityGb) GB MEMORY")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(.cyan)
                        .accessibilityLabel("Total memory capacity \(viewModel.totalMemoryCapacityGb) gigabytes")
                }

                ForEach(orderedStatuses) { status in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(shortHostname(status.hostname))
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text("\(status.totalWattage, specifier: "%.0f")W")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundColor(colorForWattage(status.totalWattage))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }

                if serverHistory.count > 1 {
                    Chart(serverHistory) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Watts", point.watts)
                        )
                        .foregroundStyle(by: .value("Server", point.server))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .frame(height: 54)
                }
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 12)
        }
    }

    private func serverPage(_ status: GPUStatus) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text(shortHostname(status.hostname).uppercased())
                        .font(.caption2.weight(.heavy))
                        .lineLimit(1)
                }

                if let capacity = status.memoryCapacityLabel {
                    Text(capacity)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                }

                Text("\(status.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundColor(colorForWattage(status.totalWattage))
                    .contentTransition(.numericText())

                if let workload = vengeanceWorkload(for: status) {
                    Label(workload.label, systemImage: workload.symbol)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(workload.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(workload.color.opacity(0.15), in: Capsule())
                }

                ForEach(status.gpus, id: \.gpuId) { gpu in
                    gpuCard(gpu, server: status.hostname)
                }
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 14)
        }
    }

    private func gpuCard(_ gpu: GPU, server: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("GPU \(gpu.gpuId)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(gpu.utilizationPercent)%")
                    .font(.system(.caption, design: .monospaced).weight(.heavy))
                    .foregroundColor(colorForUtilization(gpu.utilizationPercent))
            }

            ProgressView(value: Double(min(max(gpu.utilizationPercent, 0), 100)), total: 100)
                .tint(colorForUtilization(gpu.utilizationPercent))
                .accessibilityLabel("GPU utilization")
                .accessibilityValue("\(gpu.utilizationPercent) percent")

            if let memory = gpu.memoryFreeMb {
                HStack(alignment: .firstTextBaseline) {
                    Text(memoryLabel(for: server))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatMemory(memory))
                        .font(.system(.body, design: .monospaced).weight(.heavy))
                        .foregroundColor(.cyan)
                }

                let history = memoryHistory(server: server, gpuId: gpu.gpuId)
                if history.count > 1 {
                    Chart(history) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Free memory", point.freeMb)
                        )
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: memoryDomain(for: history))
                    .frame(height: 36)
                }
            } else {
                Text("GPU MEMORY NOT REPORTED")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
    }

    private var serverHistory: [WattageDataPoint] {
        viewModel.historicalData.filter { $0.watts.isFinite && $0.server != "Total" }
    }

    private func memoryHistory(server: String, gpuId: Int) -> [MemoryDataPoint] {
        viewModel.memoryHistoricalData.filter { $0.server == server && $0.gpuId == gpuId }
    }

    private func memoryLabel(for server: String) -> String {
        server.lowercased().contains("spark") ? "FREE UNIFIED MEMORY" : "FREE GPU MEMORY"
    }

    private func memoryDomain(for history: [MemoryDataPoint]) -> ClosedRange<Int> {
        guard let low = history.map(\.freeMb).min(), let high = history.map(\.freeMb).max() else {
            return 0...1024
        }
        let padding = max((high - low) / 5, 256)
        return max(0, low - padding)...(high + padding)
    }

    private func vengeanceWorkload(for status: GPUStatus) -> (label: String, symbol: String, color: Color)? {
        guard status.hostname.lowercased().contains("vengeance") || status.ipAddress == "192.168.6.40" else {
            return nil
        }
        if status.totalWattage > 400 {
            return ("Doing Mostly Highly Parallel Math", "bolt.fill", .orange)
        }
        if status.totalWattage >= 200 {
            return ("Mix of Memory and Math", "arrow.triangle.2.circlepath", .purple)
        }
        if status.totalWattage >= 100 {
            return ("Doing Memory Stuff", "arrow.left.arrow.right", .cyan)
        }
        return nil
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
        mb >= 1024 ? String(format: "%.1f GB", Double(mb) / 1024.0) : "\(mb) MB"
    }

    private func shortHostname(_ hostname: String) -> String {
        hostname.count > 13 ? String(hostname.prefix(11)) + "…" : hostname
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
