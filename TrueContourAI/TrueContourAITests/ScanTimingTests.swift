import XCTest
@testable import TrueContourAI

final class ScanTimingTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "ScanTimingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        tempDir = nil
        suiteName = nil
        super.tearDown()
    }

    func testScanTimingClearsOnCancel() {
        let vc = makeViewController()
        vc._recordScanStartedForTesting()
        XCTAssertNotNil(vc._scanStartTimeForTesting())

        vc._recordScanCanceledForTesting()
        XCTAssertNil(vc._scanStartTimeForTesting())
    }

    func testScanTimingClearsOnComplete() {
        let vc = makeViewController()
#if DEBUG
        ScanDiagnostics.reset()
#endif
        vc._recordScanStartedForTesting()
        XCTAssertNotNil(vc._scanStartTimeForTesting())

        vc._recordScanCompletedForTesting()
        XCTAssertNil(vc._scanStartTimeForTesting())
#if DEBUG
        let snapshot = ScanDiagnostics.snapshot()
        XCTAssertNotNil(snapshot.scanStartTimestamp)
        XCTAssertNotNil(snapshot.finalizeCompletionTimestamp)
#endif
    }

    private func makeViewController() -> ViewController {
        let scanService = ScanService(scansRootURL: tempDir, defaults: defaults)
        let deps = AppDependencies(
            scanService: scanService,
            settingsStore: SettingsStore(),
            earServiceFactory: { nil }
        )
        return ViewController(dependencies: deps)
    }
}

final class OneShotExpectation {
    private let expectation: XCTestExpectation
    private var isFulfilled = false

    init(_ expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func fulfill() {
        guard !isFulfilled else { return }
        isFulfilled = true
        expectation.fulfill()
    }
}

enum AsyncPoll {
    static func waitUntil(
        timeout: TimeInterval,
        pollEvery: TimeInterval = 0.05,
        condition: @escaping () -> Bool
    ) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(pollEvery))
        }
        return condition()
    }
}
