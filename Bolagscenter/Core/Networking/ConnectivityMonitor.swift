import Foundation
import Network
import Observation

enum ConnectivityState: Equatable, Sendable {
    case checking
    case online
    case offline
}

@MainActor
@Observable
final class ConnectivityMonitor {
    private(set) var state: ConnectivityState = .checking

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(
        label: "com.kbhelios.northbridge.connectivity",
        qos: .utility
    )

    init() {
        #if DEBUG
        if UITestLaunchConfiguration.isOffline {
            state = .offline
            return
        }
        #endif

        monitor.pathUpdateHandler = { [weak self] path in
            let nextState: ConnectivityState =
                path.status == .satisfied ? .online : .offline
            Task { @MainActor [weak self] in
                self?.state = nextState
            }
        }
        monitor.start(queue: queue)
    }

}
