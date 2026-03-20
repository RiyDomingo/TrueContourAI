import XCTest
import UIKit
@testable import TrueContourAI

final class HomeViewModelTests: XCTestCase {
    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var scanRepository: ScanRepository!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "HomeViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        scanRepository = ScanRepository(scansRootURL: tempDir, defaults: defaults)
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        scanRepository = nil
        defaults = nil
        suiteName = nil
        tempDir = nil
        super.tearDown()
    }

    func testDefaultSortModeUsesDateNewest() throws {
        let older = try createScanFolder(name: "older", modifiedAt: Date(timeIntervalSince1970: 100), confidence: 0.95)
        let newer = try createScanFolder(name: "newer", modifiedAt: Date(timeIntervalSince1970: 200), confidence: 0.60)

        let vm = HomeViewModel(scanService: scanRepository)
        waitForLoadedState(vm, trigger: .viewDidLoad)

        XCTAssertEqual(vm.state.viewData.selectedSortMode, .dateNewest)
        XCTAssertEqual(vm.scans.first?.folderURL, newer)
        XCTAssertEqual(vm.scans.last?.folderURL, older)
    }

    func testQualitySortModeUsesHighestConfidenceFirst() throws {
        let lowQualityNewer = try createScanFolder(name: "low-newer", modifiedAt: Date(timeIntervalSince1970: 300), confidence: 0.55)
        let highQualityOlder = try createScanFolder(name: "high-older", modifiedAt: Date(timeIntervalSince1970: 200), confidence: 0.92)

        let vm = HomeViewModel(scanService: scanRepository)
        waitForLoadedState(vm, trigger: .viewDidLoad)
        vm.send(.sortChanged(.qualityHighest))

        XCTAssertEqual(vm.state.viewData.selectedSortMode, .qualityHighest)
        XCTAssertEqual(vm.scans.first?.folderURL, highQualityOlder)
        XCTAssertEqual(vm.scans.last?.folderURL, lowQualityNewer)
    }

    func testGoodPlusFilterHidesLowQualityScans() throws {
        _ = try createScanFolder(name: "low", modifiedAt: Date(timeIntervalSince1970: 100), confidence: 0.60)
        let high = try createScanFolder(name: "high", modifiedAt: Date(timeIntervalSince1970: 200), confidence: 0.88)

        let vm = HomeViewModel(scanService: scanRepository)
        waitForLoadedState(vm, trigger: .viewDidLoad)
        vm.send(.filterChanged(.goodPlus))

        XCTAssertEqual(vm.state.viewData.selectedFilterMode, .goodPlus)
        XCTAssertEqual(vm.scans.count, 1)
        XCTAssertEqual(vm.scans.first?.folderURL, high)
    }

    func testGoodPlusFilterCanYieldEmptyResultsWhileScansExist() throws {
        _ = try createScanFolder(name: "low-a", modifiedAt: Date(timeIntervalSince1970: 100), confidence: 0.50)
        _ = try createScanFolder(name: "low-b", modifiedAt: Date(timeIntervalSince1970: 200), confidence: 0.70)

        let vm = HomeViewModel(scanService: scanRepository)
        waitForLoadedState(vm, trigger: .viewDidLoad)
        vm.send(.filterChanged(.goodPlus))

        XCTAssertEqual(vm.totalScanCount, 2)
        XCTAssertTrue(vm.scans.isEmpty)
        XCTAssertTrue(vm.state.viewData.isEmpty)
        XCTAssertTrue(vm.state.viewData.isFilteredEmpty)
    }

    func testViewWillAppearRefreshesAndEmitsDiagnosticsEffect() throws {
        _ = try createScanFolder(name: "scan", modifiedAt: Date(timeIntervalSince1970: 100), confidence: 0.85)

        let vm = HomeViewModel(scanService: scanRepository)
        waitForLoadedState(vm, trigger: .viewDidLoad)

        let effectExpectation = expectation(description: "home-effect")
        vm.onEffect = { effect in
            guard effect == .refreshDiagnostics else { return }
            effectExpectation.fulfill()
        }

        vm.send(.viewWillAppear)
        wait(for: [effectExpectation], timeout: 2.0)
    }

    func testExternalScanChangeRefreshesAndEmitsDiagnosticsEffect() throws {
        let vm = HomeViewModel(scanService: scanRepository)
        waitForLoadedState(vm, trigger: .viewDidLoad)

        _ = try createScanFolder(name: "new-scan", modifiedAt: Date(timeIntervalSince1970: 100), confidence: 0.9)

        let effectExpectation = expectation(description: "external-change-effect")
        vm.onEffect = { effect in
            guard effect == .refreshDiagnostics else { return }
            effectExpectation.fulfill()
        }

        waitForLoadedState(vm, trigger: .scansChangedExternally)
        wait(for: [effectExpectation], timeout: 2.0)
        XCTAssertEqual(vm.totalScanCount, 1)
    }

    func testLoadedScanProducesOpenEnabledRow() throws {
        _ = try createScanFolder(name: "seeded", modifiedAt: Date(timeIntervalSince1970: 300), confidence: 0.70)

        let vm = HomeViewModel(scanService: scanRepository)
        waitForLoadedState(vm, trigger: .viewDidLoad)

        XCTAssertEqual(vm.state.viewData.scanRows.count, 1)
        XCTAssertTrue(vm.state.viewData.scanRows[0].isOpenEnabled)
    }

    private func waitForLoadedState(
        _ vm: HomeViewModel,
        trigger action: HomeAction,
        timeout: TimeInterval = 2.0
    ) {
        let exp = expectation(description: "home-loaded-\(UUID().uuidString)")
        vm.onStateChange = { state in
            guard state.status == .loaded else { return }
            exp.fulfill()
        }
        vm.send(action)
        wait(for: [exp], timeout: timeout)
        vm.onStateChange = nil
    }

    @discardableResult
    private func createScanFolder(name: String, modifiedAt: Date, confidence: Float) throws -> URL {
        let folder = tempDir.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: folder.path)
        let summary = ScanSummary(
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
        let gltf = """
        {"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[]}]}
        """
        try gltf.data(using: .utf8)?.write(to: folder.appendingPathComponent("scene.gltf"), options: [.atomic])
        return folder
    }
}

@MainActor
final class HomeAssemblerTests: XCTestCase {
    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        suiteName = "HomeAssemblerTests.\(UUID().uuidString)"
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
        tempDir = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testHomeRefreshesAfterExternalScanChange() throws {
        let repository = ScanRepository(scansRootURL: tempDir, defaults: defaults)
        let exporter = ScanExporterService(scansRootURL: tempDir, defaults: defaults)
        let dependencies = AppDependencies(
            scanRepository: repository,
            scanExporter: exporter,
            settingsStore: SettingsStore(defaults: defaults),
            earServiceFactory: { nil }
        )
        let settingsAssembler = SettingsAssembler(dependencies: dependencies)
        let scanAssembler = ScanAssembler(dependencies: dependencies)
        let previewAssembler = PreviewAssembler(dependencies: dependencies)
        let viewController = HomeAssembler(
            dependencies: dependencies,
            makeSettingsViewController: { onScansChanged in
                settingsAssembler.makeSettingsViewController(onScansChanged: onScansChanged)
            },
            makeScanCoordinator: {
                scanAssembler.makeScanCoordinator()
            },
            makePreviewCoordinator: { presenter, scanFlowState, previewSessionState, onToast in
                previewAssembler.makePreviewCoordinator(
                    presenter: presenter,
                    scanFlowState: scanFlowState,
                    previewSessionState: previewSessionState,
                    onToast: onToast
                )
            }
        ).makeHomeViewController()

        viewController.loadViewIfNeeded()
        XCTAssertEqual(viewController.debug_homeViewModel().totalScanCount, 0)

        _ = try createScanFolder(in: tempDir, name: "new-scan", modifiedAt: Date(), confidence: 0.9)
        viewController.debug_triggerScansChanged()

        let refreshed = AsyncPoll.waitUntil(timeout: 2.0) {
            viewController.debug_homeViewModel().totalScanCount == 1
        }
        XCTAssertTrue(refreshed)
        XCTAssertEqual(viewController.debug_homeViewModel().scans.count, 1)
    }

    @discardableResult
    private func createScanFolder(in root: URL, name: String, modifiedAt: Date, confidence: Float) throws -> URL {
        let folder = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: folder.path)
        let summary = ScanSummary(
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
        let gltf = """
        {"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[]}]}
        """
        try gltf.data(using: .utf8)?.write(to: folder.appendingPathComponent("scene.gltf"), options: [.atomic])
        return folder
    }
}
