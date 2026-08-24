import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()

    private let serverColors: [Color] = [.blue, .green, .orange]
    private let serverOrder = ["vengeance", "spark-1", "spark-2", "9a96", "96c6"]

    private var orderedStatuses: [GPUStatus] {
        viewModel.serverStatuses.sorted { a, b in
            let aIndex = serverOrder.firstIndex { a.hostname.lowercased().contains($0) } ?? serverOrder.count
            let bIndex = serverOrder.firstIndex { b.hostname.lowercased().contains($0) } ?? serverOrder.count
            return aIndex < bIndex
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            serverColumns.frame(maxHeight: .infinity)
            powerHistoryChart.frame(height: 132)
        }
        .frame(minWidth: 900, idealWidth: 1100, minHeight: 560, idealHeight: 650)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    private var headerBar: some View {
        HStack(spacing: 18) {
            Text("WATTS")
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
            Spacer(minLength: 20)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("TOTAL")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\(viewModel.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: 40, weight: .heavy, design: .monospaced))
                    .foregroundColor(colorForWattage(viewModel.totalWattage))
                    .contentTransition(.numericText())
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("MEMORY CAPACITY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\(viewModel.totalMemoryCapacityGb) GB")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            Spacer(minLength: 20)
            HStack(spacing: 4) {
                Text("POLL")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\(Int(viewModel.pollingInterval))s")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(width: 24, alignment: .trailing)
                Stepper("", value: $viewModel.pollingInterval, in: 1...30, step: 1)
                    .labelsHidden()
                    .controlSize(.small)
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
    }

    private var serverColumns: some View {
        Group {
            if orderedStatuses.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("Connecting to servers…")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(orderedStatuses) { status in
                        serverColumn(status, color: colorForServer(status.hostname))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
    }

    private func serverColumn(_ status: GPUStatus, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                    .shadow(color: .green, radius: 4)
                Text(status.hostname.uppercased())
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let capacity = status.memoryCapacityLabel {
                    Text(capacity)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 3)
                Text("\(status.totalWattage, specifier: "%.0f")W")
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(colorForWattage(status.totalWattage))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            if let workload = vengeanceWorkload(for: status) {
                Label(workload.label, systemImage: workload.symbol)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(workload.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(workload.color.opacity(0.13), in: Capsule())
                    .overlay(Capsule().strokeBorder(workload.color.opacity(0.45)))
            }

            if let note = status.note, !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notePanel(note.text, color: color)
            }
            if let processes = status.topProcesses, !processes.isEmpty {
                processPanel(processes)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(status.gpus, id: \.gpuId) { gpu in
                    gpuPanel(gpu, server: status.hostname)
                }
            }
            .frame(height: 160)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.45), lineWidth: 2.5))
    }

    private func notePanel(_ text: String, color: Color) -> some View {
        Label(text, systemImage: "note.text")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.3)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Status note: \(text)")
    }

    private func processPanel(_ processes: [GPUProcess]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOP GPU PROCESSES")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            HStack(spacing: 5) {
                ForEach(Array(processes.prefix(3).enumerated()), id: \.offset) { index, process in
                    HStack(spacing: 4) {
                        Text("\(index + 1)")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 17, height: 17)
                            .background(Color.purple, in: Circle())
                        VStack(alignment: .leading, spacing: 0) {
                            Text(process.displayName)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.head)
                                .minimumScaleFactor(0.55)
                            if let memory = process.memoryLabel {
                                Text(memory)
                                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.purple.opacity(0.30)))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Top GPU processes: \(processes.prefix(3).map(\.displayName).joined(separator: ", "))")
    }

    private func gpuPanel(_ gpu: GPU, server: String) -> some View {
        VStack(spacing: 5) {
            Text("GPU \(gpu.gpuId)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            utilizationBar(gpu.utilizationPercent)
            Spacer(minLength: 0)
            memoryPanel(gpu, server: server)
        }
        .frame(maxWidth: .infinity)
    }

    private func utilizationBar(_ percent: Int) -> some View {
        let clamped = min(max(percent, 0), 100)
        return VStack(spacing: 3) {
            HStack {
                Text("GPU LOAD")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(clamped)%")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(colorForUtilization(clamped))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(colorForUtilization(clamped))
                        .frame(width: geometry.size.width * Double(clamped) / 100)
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private func memoryPanel(_ gpu: GPU, server: String) -> some View {
        if let freeMb = gpu.memoryFreeMb {
            let history = memoryHistory(server: server, gpuId: gpu.gpuId)
            let domain = memoryDomain(for: history)
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(memoryLabel(for: server))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(formatMemory(freeMb))
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 3)
                    if let low = history.map(\.freeMb).min() {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("ROLLING LOW")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(formatMemory(low))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
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
                        .foregroundStyle(LinearGradient(
                            colors: [.cyan.opacity(0.28), .cyan.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Free memory", point.freeMb)
                        )
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartYScale(domain: domain)
                    .frame(height: 44)
                } else {
                    Text("COLLECTING HISTORY…")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.cyan.opacity(0.25)))
        } else {
            Text("GPU MEMORY NOT REPORTED")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
        }
    }

    private var powerHistoryChart: some View {
        Group {
            if serverHistoricalData.isEmpty {
                Text("Collecting power history…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(serverHistoricalData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Log watts", log10(max(point.watts, 1)))
                    )
                    .foregroundStyle(by: .value("Server", point.server))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartForegroundStyleScale(domain: chartColorDomain, range: chartColorRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel {
                            if let logValue = value.as(Double.self) {
                                Text("\(Int(pow(10, logValue)))W")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
        .background(Color.white.opacity(0.02))
    }

    private var chartColorDomain: [String] { orderedStatuses.map(\.hostname) }
    private var chartColorRange: [Color] { orderedStatuses.map { colorForServer($0.hostname) } }
    private var serverHistoricalData: [WattageDataPoint] {
        viewModel.historicalData.filter { $0.watts.isFinite && $0.server != "Total" }
    }

    private func colorForServer(_ hostname: String) -> Color {
        guard let index = orderedStatuses.firstIndex(where: { $0.hostname == hostname }) else { return .gray }
        return serverColors[index % serverColors.count]
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
        guard status.hostname.lowercased().contains("vengeance") || status.ipAddress == "192.168.6.40" else { return nil }
        if status.totalWattage > 400 { return ("Doing Mostly Highly Parallel Math", "bolt.fill", .orange) }
        if status.totalWattage >= 200 { return ("Mix of Memory and Math", "arrow.triangle.2.circlepath", .purple) }
        if status.totalWattage >= 100 { return ("Doing Memory Stuff", "arrow.left.arrow.right", .cyan) }
        return nil
    }

    private func memoryHistory(server: String, gpuId: Int) -> [MemoryDataPoint] {
        viewModel.memoryHistoricalData.filter { $0.server == server && $0.gpuId == gpuId }
    }

    private func memoryLabel(for server: String) -> String {
        server.lowercased().contains("spark") ? "FREE UNIFIED MEMORY" : "FREE GPU MEMORY"
    }

    private func memoryDomain(for history: [MemoryDataPoint]) -> ClosedRange<Int> {
        guard let low = history.map(\.freeMb).min(), let high = history.map(\.freeMb).max() else { return 0...1024 }
        let padding = max((high - low) / 5, 256)
        return max(0, low - padding)...(high + padding)
    }

    private func formatMemory(_ mb: Int) -> String {
        mb >= 1024 ? String(format: "%.1f GB", Double(mb) / 1024) : "\(mb) MB"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
