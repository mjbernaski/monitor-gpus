import Foundation
import SwiftUI

@MainActor
class GPUMonitorViewModel: ObservableObject {
    @Published var serverStatuses: [GPUStatus] = []
    @Published var historicalData: [WattageDataPoint] = []
    @Published var isLoading = false
    @Published var pollingInterval: Double = 1.0 {
        didSet {
            restartMonitoring()
        }
    }

    private var timer: Timer?
    private let maxDataPoints = 60

    var totalWattage: Double {
        serverStatuses.reduce(0) { $0 + $1.totalWattage }
    }

    func startMonitoring() {
        Task {
            await fetchData()
        }

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchData()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func restartMonitoring() {
        guard timer != nil else { return }
        stopMonitoring()
        startMonitoring()
    }

    private func fetchData() async {
        isLoading = true
        let statuses = await GPUService.shared.fetchAllServers()
        serverStatuses = statuses.sorted { $0.hostname < $1.hostname }

        await LoggingService.shared.log(statuses: statuses)

        let timestamp = Date()
        var totalWatts = 0.0

        for status in statuses {
            let dataPoint = WattageDataPoint(
                timestamp: timestamp,
                server: status.hostname,
                watts: status.totalWattage
            )
            historicalData.append(dataPoint)
            totalWatts += status.totalWattage
        }

        let totalDataPoint = WattageDataPoint(
            timestamp: timestamp,
            server: "Total",
            watts: totalWatts
        )
        historicalData.append(totalDataPoint)

        if historicalData.count > maxDataPoints * (statuses.count + 1) {
            let removeCount = historicalData.count - (maxDataPoints * (statuses.count + 1))
            historicalData.removeFirst(removeCount)
        }

        isLoading = false
    }
}
