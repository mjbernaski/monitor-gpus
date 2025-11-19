import Foundation

actor LoggingService {
    static let shared = LoggingService()

    private let logFileURL: URL
    private var isInitialized = false

    private init() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDirectory = documentsPath.appendingPathComponent("GPUMonitorLogs", isDirectory: true)

        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        logFileURL = logsDirectory.appendingPathComponent("gpu_monitor_\(dateString).csv")
    }

    func log(statuses: [GPUStatus]) async {
        if !isInitialized {
            await initializeLogFile()
            isInitialized = true
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        var lines: [String] = []

        for status in statuses {
            for gpu in status.gpus {
                let line = "\(timestamp),\(status.hostname),\(gpu.gpuId),\(gpu.powerDrawWatts),\(gpu.utilizationPercent),\(status.gpuCount)"
                lines.append(line)
            }
        }

        if let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        }
    }

    private func initializeLogFile() async {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: logFileURL.path) {
            let header = "timestamp,hostname,gpu_id,power_draw_watts,utilization_percent,total_gpu_count\n"
            try? header.data(using: .utf8)?.write(to: logFileURL)
        }
    }

    func getLogFileURL() -> URL {
        return logFileURL
    }
}
