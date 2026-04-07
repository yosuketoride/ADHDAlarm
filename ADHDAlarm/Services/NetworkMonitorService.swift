import Foundation
import Network
import Observation

/// ネットワーク接続状態を監視する
@Observable @MainActor
final class NetworkMonitorService {
    var isOnline = true

    var isOffline: Bool { !isOnline }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.yosuke.WasurebouAlarm.network-monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
