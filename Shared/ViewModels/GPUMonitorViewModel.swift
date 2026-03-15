import Foundation
import SwiftUI

@MainActor
class GPUMonitorViewModel: ObservableObject {
    @Published var serverStatuses: [GPUStatus] = []
    @Published var historicalData: [WattageDataPoint] = []
    @Published var isLoading = false

    #if os(watchOS)
    @Published var pollingInterval: Double = 5.0 {
        didSet { restartMonitoring() }
    }
    private let maxDataPoints = 30
    #elseif os(tvOS)
    @Published var pollingInterval: Double = 2.0 {
        didSet { restartMonitoring() }
    }
    private let maxDataPoints = 120
    #else
    @Published var pollingInterval: Double = 1.0 {
        didSet { restartMonitoring() }
    }
    private let maxDataPoints = 60
    #endif

    private var timer: Timer?
    private var isFetching = false  // Prevent concurrent fetches
    private var fetchTask: Task<Void, Never>?  // Track current fetch task

    var totalWattage: Double {
        serverStatuses.reduce(0) { $0 + $1.totalWattage }
    }

    func startMonitoring() {
        // Initial fetch
        fetchTask = Task {
            await fetchData()
        }

        // Schedule repeating timer
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Prevent overlapping fetches
                guard !self.isFetching else {
                    print("Skipping fetch - previous fetch still in progress")
                    return
                }

                self.fetchTask = Task {
                    await self.fetchData()
                }
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        fetchTask?.cancel()
        fetchTask = nil
        isFetching = false
    }

    private func restartMonitoring() {
        guard timer != nil else { return }
        stopMonitoring()
        startMonitoring()
    }

    private func fetchData() async {
        // Check if already fetching
        guard !isFetching else { return }

        // Check if task was cancelled
        guard !Task.isCancelled else { return }

        isFetching = true
        isLoading = true

        defer {
            isFetching = false
            isLoading = false
        }

        let statuses = await GPUService.shared.fetchAllServers()

        // Check cancellation after async work
        guard !Task.isCancelled else { return }

        // Only sort if we have data
        if !statuses.isEmpty {
            serverStatuses = statuses.sorted { $0.hostname < $1.hostname }
        }

        // Only log if we have valid data
        #if os(macOS) || os(iOS)
        if !statuses.isEmpty {
            await LoggingService.shared.log(statuses: statuses)
        }
        #endif

        let timestamp = Date()
        var newDataPoints: [WattageDataPoint] = []
        var totalWatts = 0.0

        for status in statuses {
            let dataPoint = WattageDataPoint(
                timestamp: timestamp,
                server: status.hostname,
                watts: status.totalWattage
            )
            newDataPoints.append(dataPoint)
            totalWatts += status.totalWattage
        }

        // Add total data point (not on watchOS)
        #if !os(watchOS)
        if !statuses.isEmpty {
            let totalDataPoint = WattageDataPoint(
                timestamp: timestamp,
                server: "Total",
                watts: totalWatts
            )
            newDataPoints.append(totalDataPoint)
        }
        #endif

        // Append new data points
        historicalData.append(contentsOf: newDataPoints)

        // Trim historical data
        #if os(watchOS)
        let expectedServersCount = statuses.isEmpty ? 0 : statuses.count
        #else
        let expectedServersCount = statuses.isEmpty ? 0 : statuses.count + 1
        #endif
        if expectedServersCount > 0 {
            let maxTotalPoints = maxDataPoints * expectedServersCount
            if historicalData.count > maxTotalPoints {
                let removeCount = historicalData.count - maxTotalPoints
                historicalData.removeFirst(removeCount)
            }
        } else {
            if historicalData.count > maxDataPoints {
                historicalData.removeFirst(historicalData.count - maxDataPoints)
            }
        }
    }
}
