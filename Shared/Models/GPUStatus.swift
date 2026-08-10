import Foundation

struct GPUStatus: Codable, Identifiable {
    var id: String { hostname }
    let hostname: String
    var ipAddress: String?
    let timestamp: String
    let gpuCount: Int
    let gpus: [GPU]
    let topProcesses: [GPUProcess]?
    let note: StatusNote?

    enum CodingKeys: String, CodingKey {
        case hostname
        case ipAddress
        case timestamp
        case gpuCount = "gpu_count"
        case gpus
        case topProcesses = "top_processes"
        case note
    }

    var totalWattage: Double {
        gpus.reduce(0) { $0 + $1.powerDrawWatts }
    }
}

struct StatusNote: Codable {
    let text: String
    let updatedAt: String
}

struct GPU: Codable {
    let gpuId: Int
    let powerDrawWatts: Double
    let memoryFreeMb: Int?
    let utilizationPercent: Int

    enum CodingKeys: String, CodingKey {
        case gpuId = "gpu_id"
        case powerDrawWatts = "power_draw_watts"
        case memoryFreeMb = "memory_free_mb"
        case utilizationPercent = "utilization_percent"
    }
}

/// Agents report top processes either as a bare name (`"VLLM::Worker_TP0"`) or
/// as an object with pid and memory. Both shapes decode into this.
struct GPUProcess: Codable, Identifiable {
    let name: String
    let pid: Int?
    let memoryMb: Int?

    var id: String { "\(name)-\(pid ?? -1)" }

    enum CodingKeys: String, CodingKey {
        case name
        case pid
        case memoryMb = "memory_mb"
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let bareName = try? single.decode(String.self) {
            name = bareName
            pid = nil
            memoryMb = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        pid = try container.decodeIfPresent(Int.self, forKey: .pid)
        memoryMb = try container.decodeIfPresent(Int.self, forKey: .memoryMb)
    }

    var displayName: String { name.processDisplayName }

    var memoryLabel: String? {
        guard let memoryMb, memoryMb > 0 else { return nil }
        if memoryMb >= 1024 {
            return String(format: "%.1f GB", Double(memoryMb) / 1024)
        }
        return "\(memoryMb) MB"
    }
}

extension String {
    /// Process names arrive as full executable paths on Windows hosts
    /// (`C:\Windows\System32\dwm.exe`). The leading path is noise; show the
    /// executable name instead.
    var processDisplayName: String {
        let component = split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? self
        let trimmed = component.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return self }

        if trimmed.lowercased().hasSuffix(".exe") {
            return String(trimmed.dropLast(4))
        }
        return trimmed
    }
}

struct WattageDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let server: String
    let watts: Double
}

struct MemoryDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let server: String
    let gpuId: Int
    let freeMb: Int
}
