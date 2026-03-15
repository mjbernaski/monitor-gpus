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
    private let urlSession: URLSession

    private init() {
        let config = Self.loadConfig()
        self.servers = config.servers
        self.port = config.port
        self.endpoint = config.endpoint

        // Configure URLSession with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5.0  // 5 second timeout
        configuration.timeoutIntervalForResource = 10.0
        self.urlSession = URLSession(configuration: configuration)
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
            print("Invalid URL for server: \(server)")
            return nil
        }

        do {
            let (data, response) = try await urlSession.data(from: url)

            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response from \(server)")
                return nil
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("HTTP error from \(server): \(httpResponse.statusCode)")
                return nil
            }

            let decoder = JSONDecoder()
            var status = try decoder.decode(GPUStatus.self, from: data)
            status.ipAddress = server
            return status
        } catch let error as URLError {
            // More specific error handling for network issues
            switch error.code {
            case .timedOut:
                print("Timeout fetching from \(server)")
            case .cannotConnectToHost, .networkConnectionLost:
                print("Cannot connect to \(server)")
            default:
                print("Network error from \(server): \(error.localizedDescription)")
            }
            return nil
        } catch {
            print("Error decoding response from \(server): \(error)")
            return nil
        }
    }
}
