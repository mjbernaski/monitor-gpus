import WidgetKit
import SwiftUI

struct GPUEntry: TimelineEntry {
    let date: Date
    let servers: [GPUStatus]
    let totalWattage: Double
}

struct GPUMonitorProvider: TimelineProvider {
    func placeholder(in context: Context) -> GPUEntry {
        GPUEntry(date: Date(), servers: [], totalWattage: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (GPUEntry) -> Void) {
        Task {
            let servers = await GPUService.shared.fetchAllServers()
            let total = servers.reduce(0) { $0 + $1.totalWattage }
            let entry = GPUEntry(date: Date(), servers: servers, totalWattage: total)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GPUEntry>) -> Void) {
        Task {
            let servers = await GPUService.shared.fetchAllServers()
            let total = servers.reduce(0) { $0 + $1.totalWattage }
            let entry = GPUEntry(date: Date(), servers: servers, totalWattage: total)
            
            // Refresh every 30 seconds
            let nextUpdate = Calendar.current.date(byAdding: .second, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct GPUMonitorWidgetEntryView: View {
    var entry: GPUEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                Text("GPU Monitor")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Text("\(Int(entry.totalWattage))W")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.green)
            
            Text("Total Power")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(entry.servers.count) servers")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(.black.gradient, for: .widget)
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Left side - total
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    Text("GPU Monitor")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Text("\(Int(entry.totalWattage))W")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                Text("Total Power")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Right side - servers
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.servers.prefix(3)) { server in
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(server.hostname)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(server.totalWattage))W")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                
                if entry.servers.isEmpty {
                    Text("No servers connected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.black.gradient, for: .widget)
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                Text("GPU Monitor")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(entry.totalWattage))W Total")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            Divider()
            
            if entry.servers.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "wifi.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No servers connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.servers) { server in
                    serverRow(server)
                }
            }
            
            Spacer()
            
            Text("Updated: \(entry.date.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(.black.gradient, for: .widget)
    }

    private func serverRow(_ server: GPUStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text(server.hostname)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(server.totalWattage))W")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 12) {
                ForEach(server.gpus, id: \.gpuId) { gpu in
                    HStack(spacing: 4) {
                        Text("GPU \(gpu.gpuId)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(gpu.powerDrawWatts))W")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("\(gpu.utilizationPercent)%")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

@main
struct GPUMonitorWidgetBundle: Widget {
    let kind: String = "GPUMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GPUMonitorProvider()) { entry in
            GPUMonitorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GPU Monitor")
        .description("Monitor GPU power consumption across your servers.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
