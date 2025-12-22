import Foundation

// MARK: - Models

struct ServerConfig: Codable {
    let servers: [String]
    let port: Int
    let endpoint: String
}

struct GPUStatus: Codable {
    let hostname: String
    var ipAddress: String?
    let timestamp: String
    let gpuCount: Int
    let gpus: [GPU]

    enum CodingKeys: String, CodingKey {
        case hostname, ipAddress, timestamp
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

// MARK: - ANSI Colors

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case orange = "\u{001B}[38;5;208m"
    case red = "\u{001B}[31m"
    case cyan = "\u{001B}[36m"
    case gray = "\u{001B}[90m"
}

func colored(_ text: String, _ color: ANSIColor) -> String {
    "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
}

func colorForWattage(_ watts: Double) -> ANSIColor {
    switch watts {
    case ..<50: return .green
    case 50..<100: return .yellow
    case 100..<200: return .orange
    default: return .red
    }
}

// MARK: - GPU Service

actor GPUServiceCLI {
    let servers: [String]
    let port: Int
    let endpoint: String

    init(servers: [String], port: Int, endpoint: String) {
        self.servers = servers
        self.port = port
        self.endpoint = endpoint
    }

    func fetchAllServers() async -> [GPUStatus] {
        await withTaskGroup(of: GPUStatus?.self) { group in
            for server in servers {
                group.addTask {
                    await self.fetchStatus(from: server)
                }
            }

            var results: [GPUStatus] = []
            for await result in group {
                if let status = result {
                    results.append(status)
                }
            }
            return results.sorted { $0.hostname < $1.hostname }
        }
    }

    private func fetchStatus(from server: String) async -> GPUStatus? {
        guard let url = URL(string: "http://\(server):\(port)\(endpoint)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            var status = try JSONDecoder().decode(GPUStatus.self, from: data)
            status.ipAddress = server
            return status
        } catch {
            return nil
        }
    }
}

// MARK: - Config Loading

func loadConfig() -> ServerConfig {
    let configPaths = [
        "./servers.json",
        Bundle.main.bundlePath + "/../servers.json",
        FileManager.default.currentDirectoryPath + "/servers.json"
    ]

    for path in configPaths {
        if let data = FileManager.default.contents(atPath: path),
           let config = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            return config
        }
    }

    // Default fallback
    return ServerConfig(
        servers: ["192.168.5.40", "192.168.5.46", "192.168.6.40"],
        port: 9999,
        endpoint: "/gpu-status"
    )
}

// MARK: - Display

func clearScreen() {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
}

func displayStatus(_ statuses: [GPUStatus]) {
    let totalWattage = statuses.reduce(0.0) { $0 + $1.totalWattage }
    let wattageColor = colorForWattage(totalWattage)

    print(colored("GPU Monitor", .bold), colored("│", .dim),
          "Total:", colored(String(format: "%.0fW", totalWattage), wattageColor))
    print(colored(String(repeating: "─", count: 50), .dim))

    if statuses.isEmpty {
        print(colored("  No servers responding", .yellow))
    } else {
        for status in statuses {
            let wattColor = colorForWattage(status.totalWattage)
            let dot = colored("●", .green)
            let host = status.hostname.padding(toLength: 15, withPad: " ", startingAt: 0)
            let watts = String(format: "%6.0fW", status.totalWattage)
            let gpuInfo = colored("\(status.gpuCount) GPU\(status.gpuCount == 1 ? "" : "s")", .gray)

            print("  \(dot) \(host) \(colored(watts, wattColor))  \(gpuInfo)")

            // Show per-GPU details
            for gpu in status.gpus {
                let gpuWattColor = colorForWattage(gpu.powerDrawWatts)
                let util = "\(gpu.utilizationPercent)%"
                print(colored("      └─ GPU \(gpu.gpuId): ", .dim) +
                      colored(String(format: "%.0fW", gpu.powerDrawWatts), gpuWattColor) +
                      colored(" @ \(util)", .dim))
            }
        }
    }
    print(colored(String(repeating: "─", count: 50), .dim))
}

// MARK: - CLI Arguments

struct CLIOptions {
    var watch: Bool = false
    var interval: Int = 1
    var help: Bool = false
}

func parseArgs() -> CLIOptions {
    var options = CLIOptions()
    var args = CommandLine.arguments.dropFirst()

    while let arg = args.first {
        args = args.dropFirst()
        switch arg {
        case "-w", "--watch":
            options.watch = true
        case "-i", "--interval":
            if let next = args.first, let val = Int(next) {
                options.interval = max(1, val)
                args = args.dropFirst()
            }
        case "-h", "--help":
            options.help = true
        default:
            break
        }
    }

    return options
}

func printHelp() {
    print("""
    \(colored("gpu-cli", .bold)) - GPU wattage monitor

    \(colored("USAGE:", .cyan))
        gpu-cli [OPTIONS]

    \(colored("OPTIONS:", .cyan))
        -w, --watch         Continuous monitoring mode
        -i, --interval N    Polling interval in seconds (default: 1)
        -h, --help          Show this help message

    \(colored("EXAMPLES:", .cyan))
        gpu-cli                 # One-shot status check
        gpu-cli -w              # Watch mode, update every 1s
        gpu-cli -w -i 5         # Watch mode, update every 5s
    """)
}

// MARK: - Main

@main
struct GPUMonitorCLI {
    static func main() async {
        let options = parseArgs()

        if options.help {
            printHelp()
            return
        }

        let config = loadConfig()
        let service = GPUServiceCLI(
            servers: config.servers,
            port: config.port,
            endpoint: config.endpoint
        )

        if options.watch {
            // Watch mode - continuous updates
            while true {
                clearScreen()
                let statuses = await service.fetchAllServers()
                displayStatus(statuses)
                print(colored("Updating every \(options.interval)s • Ctrl+C to exit", .dim))
                try? await Task.sleep(nanoseconds: UInt64(options.interval) * 1_000_000_000)
            }
        } else {
            // One-shot mode
            let statuses = await service.fetchAllServers()
            displayStatus(statuses)
        }
    }
}
