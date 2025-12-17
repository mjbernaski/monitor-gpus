import Foundation

struct ServerConfig: Codable {
    let servers: [String]
    let port: Int
    let endpoint: String
}

actor GPUService {
    static let shared = GPUService()

    private let servers: [String]
    private let port: Int
    private let endpoint: String

    private init() {
        let config = Self.loadConfig()
        self.servers = config.servers
        self.port = config.port
        self.endpoint = config.endpoint
    }

    private static func loadConfig() -> ServerConfig {
        guard let url = Bundle.main.url(forResource: "servers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return ServerConfig(servers: ["192.168.5.40", "192.168.5.46", "192.168.6.40"], port: 9999, endpoint: "/gpu-status")
        }
        return config
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
            return results
        }
    }

    private func fetchStatus(from server: String) async -> GPUStatus? {
        guard let url = URL(string: "http://\(server):\(port)\(endpoint)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            var status = try decoder.decode(GPUStatus.self, from: data)
            status.ipAddress = server
            return status
        } catch {
            print("Error fetching from \(server): \(error)")
            return nil
        }
    }
}
