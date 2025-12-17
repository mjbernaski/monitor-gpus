import Foundation

struct GPUStatus: Codable, Identifiable {
    var id: String { hostname }
    let hostname: String
    var ipAddress: String?
    let timestamp: String
    let gpuCount: Int
    let gpus: [GPU]

    enum CodingKeys: String, CodingKey {
        case hostname
        case ipAddress
        case timestamp
        case gpuCount = "gpu_count"
        case gpus
    }

    var totalWattage: Double {
        gpus.reduce(0) { $0 + $1.powerDrawWatts }
    }
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

struct WattageDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let server: String
    let watts: Double
}
