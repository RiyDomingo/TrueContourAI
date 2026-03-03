import Foundation

final class MeshingTimeoutController {
    private var workItem: DispatchWorkItem?
    private(set) var isScheduled = false

    func start(after delay: TimeInterval, queue: DispatchQueue = .main, onTimeout: @escaping () -> Void) {
        cancel()
        isScheduled = true
        let item = DispatchWorkItem { [weak self] in
            self?.isScheduled = false
            onTimeout()
        }
        workItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
        isScheduled = false
    }
}
