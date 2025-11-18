import Foundation
import SwiftUI

@MainActor
class GPUMonitorViewModel: ObservableObject {
    @Published var serverStatuses: [GPUStatus] = []
    @Published var historicalData: [WattageDataPoint] = []
    @Published var isLoading = false

    private var timer: Timer?
    private let maxDataPoints = 60

    var totalWattage: Double {
        serverStatuses.reduce(0) { $0 + $1.totalWattage }
    }

    func startMonitoring() {
        Task {
            await fetchData()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchData()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchData() async {
        isLoading = true
        let statuses = await GPUService.shared.fetchAllServers()
        serverStatuses = statuses.sorted { $0.hostname < $1.hostname }

        let timestamp = Date()
        for status in statuses {
            let dataPoint = WattageDataPoint(
                timestamp: timestamp,
                server: status.hostname,
                watts: status.totalWattage
            )
            historicalData.append(dataPoint)
        }

        if historicalData.count > maxDataPoints * statuses.count {
            let removeCount = historicalData.count - (maxDataPoints * statuses.count)
            historicalData.removeFirst(removeCount)
        }

        isLoading = false
    }
}
