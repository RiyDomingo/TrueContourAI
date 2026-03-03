import XCTest
@testable import TrueContourAI

final class MeshingTimeoutControllerTests: XCTestCase {
    func testTimeoutFires() {
        let controller = MeshingTimeoutController()
        let fired = expectation(description: "timeout fired")

        controller.start(after: 0.01) {
            fired.fulfill()
        }

        wait(for: [fired], timeout: 1.0)
    }

    func testCancelPreventsTimeout() {
        let controller = MeshingTimeoutController()
        let fired = expectation(description: "timeout should not fire")
        fired.isInverted = true

        controller.start(after: 0.05) {
            fired.fulfill()
        }
        controller.cancel()

        wait(for: [fired], timeout: 0.1)
    }
}
