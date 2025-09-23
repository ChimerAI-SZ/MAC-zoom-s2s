import Foundation
import Combine

struct HealthMetrics: Equatable {
    var uptime: TimeInterval = 0
    var errorCount: Int = 0
    var reconnectCount: Int = 0
    var avgPingMs: Double = 0
    var queueSize: Int = 0
    var wsEvents: Int = 0
}

final class HealthMonitor: ObservableObject {
    @Published private(set) var metrics = HealthMetrics()
    private var timer: AnyCancellable?
    private var startTime = Date()
    private var queueEMA: Double = 0

    init() {
        start()
    }

    func start() {
        startTime = Date()
        timer?.cancel()
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.metrics.uptime = Date().timeIntervalSince(self.startTime)
            }
    }

    func stop() { timer?.cancel() }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async { block() } }
    }

    func recordError() { onMain { self.metrics.errorCount += 1 } }
    func recordReconnect() { onMain { self.metrics.reconnectCount += 1 } }
    func updatePing(_ ms: Double) { onMain { self.metrics.avgPingMs = ms } }
    func updateQueueSize(_ n: Int) {
        onMain {
            // 简单指数平滑，减少界面“跳动”
            if self.queueEMA == 0 { self.queueEMA = Double(n) }
            self.queueEMA = 0.7 * self.queueEMA + 0.3 * Double(n)
            self.metrics.queueSize = Int(self.queueEMA.rounded())
        }
    }
    func recordEvent() { onMain { self.metrics.wsEvents += 1 } }
}
