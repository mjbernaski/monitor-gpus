import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let serverColors: [Color] = [.blue, .green, .orange]
    private let serverOrder = ["vengeance", "spark-1", "spark-2", "9a96", "96c6"]

    private var orderedStatuses: [GPUStatus] {
        viewModel.serverStatuses.sorted { a, b in
            let aIndex = serverOrder.firstIndex(where: { a.hostname.lowercased().contains($0) }) ?? serverOrder.count
            let bIndex = serverOrder.firstIndex(where: { b.hostname.lowercased().contains($0) }) ?? serverOrder.count
            return aIndex < bIndex
        }
    }

    private var cardColumns: [GridItem] {
        horizontalSizeClass == .regular
            ? Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3)
            : [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headerCard

                if viewModel.serverStatuses.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Connecting to servers…")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    LazyVGrid(columns: cardColumns, spacing: 16) {
                        ForEach(orderedStatuses) { status in
                            serverCard(status, color: colorForServer(status.hostname))
                        }
                    }
                }

                wattageChartCard
                controlsCard
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WATTS")
                    .font(.system(.title2, design: .monospaced).weight(.heavy))
                Text("LIVE SYSTEM POWER")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("TOTAL")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                Text("\(viewModel.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: horizontalSizeClass == .regular ? 48 : 38, weight: .heavy, design: .monospaced))
                    .foregroundColor(colorForWattage(viewModel.totalWattage))
                    .contentTransition(.numericText())
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private func serverCard(_ status: GPUStatus, color: Color) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                    .shadow(color: .green, radius: 4)
                VStack(alignment: .leading, spacing: 0) {
                    Text(status.hostname.uppercased())
                        .font(.system(.headline, design: .monospaced).weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    if let ipAddress = status.ipAddress {
                        Text(ipAddress)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("\(status.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(colorForWattage(status.totalWattage))
                    .contentTransition(.numericText())
            }

            if let workload = vengeanceWorkload(for: status) {
                Label(workload.label, systemImage: workload.symbol)
                    .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                    .foregroundColor(workload.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(workload.color.opacity(0.13), in: Capsule())
                    .overlay(Capsule().strokeBorder(workload.color.opacity(0.4), lineWidth: 1.5))
            }

            if let processes = status.topProcesses, !processes.isEmpty {
                processPanel(processes)
            }

            ForEach(status.gpus, id: \.gpuId) { gpu in
                gpuCard(gpu, server: status.hostname)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(color.opacity(0.42), lineWidth: 2))
    }

    private func processPanel(_ processes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("TOP GPU PROCESSES", systemImage: "cpu")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            ForEach(Array(processes.prefix(3).enumerated()), id: \.offset) { index, process in
                HStack(spacing: 9) {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .monospaced).weight(.heavy))
                        .foregroundColor(.black)
                        .frame(width: 25, height: 25)
                        .background(Color.purple, in: Circle())

                    Text(process)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.purple.opacity(0.28), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Top GPU processes: \(processes.prefix(3).joined(separator: ", "))")
    }

    private func gpuCard(_ gpu: GPU, server: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                utilizationRing(percent: gpu.utilizationPercent)
                    .frame(width: 108, height: 108)

                VStack(alignment: .leading, spacing: 8) {
                    Text("GPU \(gpu.gpuId)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(gpu.powerDrawWatts, specifier: "%.0f")")
                            .font(.system(size: 31, weight: .heavy, design: .monospaced))
                        Text("W")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.secondary)
                    }

                    Text("GPU POWER")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }

            memoryPanel(gpu, server: server)
        }
        .padding(12)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
    }

    private func utilizationRing(percent: Int) -> some View {
        let fraction = Double(min(max(percent, 0), 100)) / 100
        let color = colorForUtilization(percent)

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 10)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(percent)%")
                    .font(.system(size: 27, weight: .heavy, design: .monospaced))
                Text("UTIL")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func memoryPanel(_ gpu: GPU, server: String) -> some View {
        if let freeMb = gpu.memoryFreeMb {
            let history = memoryHistory(server: server, gpuId: gpu.gpuId)
            let domain = memoryDomain(for: history)

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(memoryLabel(for: server))
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                        Text(formatMemory(freeMb))
                            .font(.system(size: 29, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    if let low = history.map(\.freeMb).min() {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("ROLLING LOW")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.secondary)
                            Text(formatMemory(low))
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        }
                    }
                }

                if history.count > 1 {
                    Chart(history) { point in
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            yStart: .value("Chart minimum", domain.lowerBound),
                            yEnd: .value("Free memory", point.freeMb)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan.opacity(0.28), .cyan.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Free memory", point.freeMb)
                        )
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: domain)
                    .frame(height: 76)
                    .accessibilityLabel("\(memoryLabel(for: server).capitalized) history")
                } else {
                    Text("COLLECTING HISTORY…")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                        .frame(height: 76)
                }
            }
            .padding(12)
            .background(Color.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cyan.opacity(0.24)))
        } else {
            Text("GPU MEMORY NOT REPORTED")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
        }
    }

    private var wattageChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POWER HISTORY")
                .font(.headline.weight(.heavy))

            if serverHistory.isEmpty {
                Text("Collecting data…")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(serverHistory) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Watts", point.watts)
                    )
                    .foregroundStyle(by: .value("Server", point.server))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartForegroundStyleScale(domain: chartColorDomain, range: chartColorRange)
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: horizontalSizeClass == .regular ? 300 : 230)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private var controlsCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("POLLING")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.pollingInterval, specifier: "%.0f") SECOND\(viewModel.pollingInterval == 1 ? "" : "S")")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
            }
            Slider(value: $viewModel.pollingInterval, in: 1...30, step: 1)

            Button {
                shareLogs()
            } label: {
                Label("Share Logs", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private var serverHistory: [WattageDataPoint] {
        viewModel.historicalData.filter { $0.watts.isFinite && $0.server != "Total" }
    }

    private var chartColorDomain: [String] {
        orderedStatuses.map(\.hostname)
    }

    private var chartColorRange: [Color] {
        orderedStatuses.map { colorForServer($0.hostname) }
    }

    private func colorForServer(_ hostname: String) -> Color {
        guard let index = orderedStatuses.firstIndex(where: { $0.hostname == hostname }) else { return .gray }
        return serverColors[index % serverColors.count]
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
        if status.totalWattage > 500 {
            return ("CRANKING PARALLEL MATH", "bolt.fill", .orange)
        }
        if (100...200).contains(status.totalWattage) {
            return ("MOVING MEMORY", "arrow.left.arrow.right", .cyan)
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

    private func shareLogs() {
        Task {
            let logURL = await LoggingService.shared.getLogFileURL()
            let activityVC = UIActivityViewController(activityItems: [logURL], applicationActivities: nil)
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else { return }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityVC, animated: true)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
