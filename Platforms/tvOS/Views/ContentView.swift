import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()

    private let serverColors: [Color] = [.blue, .green, .orange]

    // Preferred display order — hostnames containing these prefixes are sorted first
    private let serverOrder = ["vengeance", "spark-1", "spark-2", "9a96", "96c6"]

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
            Text("WATTS")
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
                    .font(.system(size: 76, weight: .heavy, design: .monospaced))
                    .foregroundColor(colorForWattage(status.totalWattage))
            }

            if let workload = vengeanceWorkload(for: status) {
                HStack(spacing: 10) {
                    Image(systemName: workload.symbol)
                    Text(workload.label)
                }
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundColor(workload.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(workload.color.opacity(0.13))
                        .overlay(
                            Capsule()
                                .strokeBorder(workload.color.opacity(0.45), lineWidth: 2)
                        )
                )
                .accessibilityLabel("Vengeance workload: \(workload.label)")
            }

            if let note = status.note, !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notePanel(note.text, color: color)
            }

            if let processes = status.topProcesses, !processes.isEmpty {
                processPanel(processes)
            }

            // GPU rings
            HStack(spacing: 12) {
                ForEach(status.gpus, id: \.gpuId) { gpu in
                    gpuRingCard(gpu: gpu, server: status.hostname)
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

    private func notePanel(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.3), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status note: \(text)")
    }

    private func processPanel(_ processes: [GPUProcess]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("TOP GPU PROCESSES")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white.opacity(0.45))

            HStack(spacing: 8) {
                ForEach(Array(processes.prefix(3).enumerated()), id: \.offset) { index, process in
                    HStack(spacing: 6) {
                        Text("\(index + 1)")
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                            .background(Color.purple, in: Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(process.displayName)
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                                .truncationMode(.head)
                                .minimumScaleFactor(0.55)

                            if let memory = process.memoryLabel {
                                Text(memory)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Color.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(Color.purple.opacity(0.30), lineWidth: 1.5)
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Top GPU processes: \(processes.prefix(3).map(\.displayName).joined(separator: ", "))")
    }

    private func gpuRingCard(gpu: GPU, server: String) -> some View {
        VStack(spacing: 8) {
            Text("GPU \(gpu.gpuId)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.5))

            // Utilization ring sized to avoid overlap with header
            utilizationRing(percent: gpu.utilizationPercent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(8)

            memoryPanel(gpu: gpu, server: server)
        }
    }

    @ViewBuilder
    private func memoryPanel(gpu: GPU, server: String) -> some View {
        if let memMb = gpu.memoryFreeMb {
            let history = memoryHistory(server: server, gpuId: gpu.gpuId)
            let domain = memoryDomain(for: history)

            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(memoryLabel(for: server))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                        Text(formatMemory(memMb))
                            .font(.system(size: 36, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                            .contentTransition(.numericText())
                    }

                    Spacer(minLength: 6)

                    if let low = history.map(\.freeMb).min() {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("ROLLING LOW")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.35))
                            Text(formatMemoryCompact(low))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.65))
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
                        .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: domain)
                    .frame(height: 70)
                    .accessibilityLabel("\(memoryLabel(for: server).capitalized) history")
                } else {
                    Text("COLLECTING HISTORY…")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(height: 70)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cyan.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.cyan.opacity(0.25), lineWidth: 2)
                    )
            )
        } else {
            Text("GPU MEMORY NOT REPORTED")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .frame(height: 34)
        }
    }

    private func utilizationRing(percent: Int) -> some View {
        let fraction = Double(min(percent, 100)) / 100.0
        let ringColor = colorForUtilization(percent)

        return GeometryReader { geo in
            // Scale stroke and label to the ring's actual size so the
            // percentage always fits inside the circle.
            let diameter = min(geo.size.width, geo.size.height)
            let lineWidth = max(6, diameter * 0.075)
            let inset = lineWidth + diameter * 0.06
            let fontSize = max(12, diameter * 0.30)

            ZStack {
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Filled arc
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Percentage in the center
                Text("\(percent)%")
                    .font(.system(size: fontSize, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(width: max(0, diameter - inset * 2))
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
                                y: .value("Log Watts", log10(max(dataPoint.watts, 1)))
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
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                                .foregroundStyle(Color.gray.opacity(0.2))
                            AxisValueLabel {
                                if let logVal = value.as(Double.self) {
                                    Text("\(Int(pow(10, logVal)))W")
                                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                            }
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

    private func memoryHistory(server: String, gpuId: Int) -> [MemoryDataPoint] {
        viewModel.memoryHistoricalData.filter { point in
            point.server == server && point.gpuId == gpuId
        }
    }

    private func memoryLabel(for server: String) -> String {
        server.lowercased().contains("spark") ? "FREE UNIFIED MEMORY" : "FREE GPU MEMORY"
    }

    private func memoryDomain(for history: [MemoryDataPoint]) -> ClosedRange<Int> {
        guard let low = history.map(\.freeMb).min(),
              let high = history.map(\.freeMb).max() else {
            return 0...1024
        }

        // Keep small changes visible while maintaining enough scale that normal
        // polling noise does not make the graph look alarming.
        let padding = max((high - low) / 5, 256)
        return max(0, low - padding)...(high + padding)
    }

    private func formatMemory(_ mb: Int) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", Double(mb) / 1024.0)
        }
        return "\(mb) MB"
    }

    private func formatMemoryCompact(_ mb: Int) -> String {
        mb >= 1024 ? String(format: "%.1f GB", Double(mb) / 1024.0) : "\(mb) MB"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
