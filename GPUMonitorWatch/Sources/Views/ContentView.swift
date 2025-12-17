import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var viewModel = GPUMonitorViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    totalWattageCard

                    serversList

                    if !viewModel.historicalData.isEmpty {
                        chartCard
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("GPU Monitor")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    private var totalWattageCard: some View {
        VStack(spacing: 4) {
            Text("Total Power")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("\(viewModel.totalWattage, specifier: "%.0f")")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(colorForWattage(viewModel.totalWattage))

            Text("watts")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    private var serversList: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.serverStatuses) { status in
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)

                    Text(shortHostname(status.hostname))
                        .font(.caption2)
                        .lineLimit(1)

                    Spacer()

                    Text("\(status.totalWattage, specifier: "%.0f")W")
                        .font(.system(.caption, design: .monospaced))
                        .bold()
                        .foregroundColor(colorForWattage(status.totalWattage))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("History")
                .font(.caption2)
                .foregroundColor(.secondary)

            Chart {
                ForEach(viewModel.historicalData) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("W", dataPoint.watts)
                    )
                    .foregroundStyle(by: .value("Server", shortHostname(dataPoint.server)))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.system(size: 8))
                }
            }
            .chartLegend(.hidden)
            .frame(height: 80)
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }

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

    private func shortHostname(_ hostname: String) -> String {
        if hostname.count > 10 {
            return String(hostname.prefix(8)) + "..."
        }
        return hostname
    }
}

#Preview {
    ContentView()
}
