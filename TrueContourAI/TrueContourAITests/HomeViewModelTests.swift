import XCTest
@testable import TrueContourAI

final class HomeViewModelTests: XCTestCase {
    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var scanService: ScanService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "HomeViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        scanService = ScanService(scansRootURL: tempDir, defaults: defaults)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        scanService = nil
        defaults = nil
        suiteName = nil
        tempDir = nil
        super.tearDown()
    }

    func testDefaultSortModeUsesDateNewest() throws {
        let older = try createScanFolder(name: "older", modifiedAt: Date(timeIntervalSince1970: 100), confidence: 0.95)
        let newer = try createScanFolder(name: "newer", modifiedAt: Date(timeIntervalSince1970: 200), confidence: 0.60)

        let vm = HomeViewModel(scanService: scanService)
        waitForRefresh(vm)

        XCTAssertEqual(vm.sortMode, .dateNewest)
        XCTAssertEqual(vm.scans.first?.folderURL, newer)
        XCTAssertEqual(vm.scans.last?.folderURL, older)
    }

    func testQualitySortModeUsesHighestConfidenceFirst() throws {
        let lowQualityNewer = try createScanFolder(name: "low-newer", modifiedAt: Date(timeIntervalSince1970: 300), confidence: 0.55)
        let highQualityOlder = try createScanFolder(name: "high-older", modifiedAt: Date(timeIntervalSince1970: 200), confidence: 0.92)

        let vm = HomeViewModel(scanService: scanService)
        waitForRefresh(vm)
        vm.updateSortMode(.qualityHighest)

        XCTAssertEqual(vm.sortMode, .qualityHighest)
        XCTAssertEqual(vm.scans.first?.folderURL, highQualityOlder)
        XCTAssertEqual(vm.scans.last?.folderURL, lowQualityNewer)
    }

    func testGoodPlusFilterHidesLowQualityScans() throws {
        _ = try createScanFolder(name: "low", modifiedAt: Date(timeIntervalSince1970: 100), confidence: 0.60)
        let high = try createScanFolder(name: "high", modifiedAt: Date(timeIntervalSince1970: 200), confidence: 0.88)

        let vm = HomeViewModel(scanService: scanService)
        waitForRefresh(vm)
        vm.updateFilterMode(.goodPlus)

        XCTAssertEqual(vm.filterMode, .goodPlus)
        XCTAssertEqual(vm.scans.count, 1)
        XCTAssertEqual(vm.scans.first?.folderURL, high)
    }

    func testGoodPlusFilterCanYieldEmptyResultsWhileScansExist() throws {
        _ = try createScanFolder(name: "low-a", modifiedAt: Date(timeIntervalSince1970: 100), confidence: 0.50)
        _ = try createScanFolder(name: "low-b", modifiedAt: Date(timeIntervalSince1970: 200), confidence: 0.70)

        let vm = HomeViewModel(scanService: scanService)
        waitForRefresh(vm)
        vm.updateFilterMode(.goodPlus)

        XCTAssertEqual(vm.totalScanCount, 2)
        XCTAssertTrue(vm.scans.isEmpty)
        XCTAssertTrue(vm.isEmpty)
    }

    private func waitForRefresh(_ vm: HomeViewModel, timeout: TimeInterval = 2.0) {
        let exp = expectation(description: "home-refresh")
        let oneShot = OneShotExpectation(exp)
        vm.onChange = {
            oneShot.fulfill()
        }
        vm.refresh()
        wait(for: [exp], timeout: timeout)
        vm.onChange = nil
    }

    @discardableResult
    private func createScanFolder(name: String, modifiedAt: Date, confidence: Float) throws -> URL {
        let folder = tempDir.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: folder.path)
        let summary = ScanService.ScanSummary(
            schemaVersion: 2,
            startedAt: modifiedAt,
            finishedAt: modifiedAt.addingTimeInterval(5),
            durationSeconds: 5.0,
            overallConfidence: confidence,
            completedPoses: 0,
            skippedPoses: 0,
            poseRecords: [],
            pointCountEstimate: 20_000,
            hadEarVerification: false,
            processingProfile: nil,
            derivedMeasurements: nil
        )
        let data = try JSONEncoder().encode(summary)
        try data.write(to: folder.appendingPathComponent("scan_summary.json"), options: [.atomic])
        return folder
    }
}
