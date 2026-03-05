import XCTest
@testable import TrueContourAI

final class AccessibilitySmokeTests: XCTestCase {

    func testHomeButtonsHaveAccessibilityLabels() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let scanService = ScanService(scansRootURL: tempDir)
        let deps = AppDependencies(
            scanService: scanService,
            settingsStore: SettingsStore(),
            earServiceFactory: { nil }
        )
        let vc = HomeViewController(dependencies: deps)
        _ = vc.view

        let startButton = vc.view.findView(withAccessibilityIdentifier: "startScanButton")
        let viewLastButton = vc.view.findView(withAccessibilityIdentifier: "viewLastScanButton")
        let scansFolderButton = vc.view.findView(withAccessibilityIdentifier: "openScansFolderButton")
        let sortControl = vc.view.findView(withAccessibilityIdentifier: "recentScansSortControl")
        let filterControl = vc.view.findView(withAccessibilityIdentifier: "recentScansFilterControl")

        XCTAssertNotNil(startButton)
        XCTAssertNotNil(viewLastButton)
        XCTAssertNotNil(scansFolderButton)
        XCTAssertNotNil(sortControl)
        XCTAssertNotNil(filterControl)
        XCTAssertNotNil(startButton?.accessibilityLabel)
        XCTAssertNotNil(viewLastButton?.accessibilityLabel)
        XCTAssertNotNil(scansFolderButton?.accessibilityLabel)
        XCTAssertNotNil(sortControl?.accessibilityLabel)
        XCTAssertNotNil(filterControl?.accessibilityLabel)
        XCTAssertNotNil(sortControl?.accessibilityHint)
        XCTAssertNotNil(filterControl?.accessibilityHint)

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testPreviewVerifyButtonHasAccessibilityLabelAndHint() {
        let coordinator = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: ScanService(),
            settingsStore: SettingsStore(),
            scanFlowState: ScanFlowState(),
            onToast: nil
        )
        let verifyButton = coordinator.debug_makeVerifyEarButton()
        XCTAssertEqual(verifyButton.accessibilityLabel, L("scan.preview.accessibility.verify.label"))
        XCTAssertEqual(verifyButton.accessibilityHint, L("scan.preview.accessibility.verify.hint"))
    }

    func testFitBrowSliderAppearsOnlyInDeveloperMode() {
        let hostView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))

        let defaultsOff = UserDefaults(suiteName: "FitBrowSliderOff.\(UUID().uuidString)")!
        let settingsOff = SettingsStore(defaults: defaultsOff)
        settingsOff.developerModeEnabled = false
        let coordinatorOff = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: ScanService(),
            settingsStore: settingsOff,
            scanFlowState: ScanFlowState()
        )
        XCTAssertFalse(coordinatorOff.debug_addFitControlsIfDeveloperMode(hostView: hostView))
        XCTAssertFalse(coordinatorOff.debug_hasFitBrowSlider())

        let defaultsOn = UserDefaults(suiteName: "FitBrowSliderOn.\(UUID().uuidString)")!
        let settingsOn = SettingsStore(defaults: defaultsOn)
        settingsOn.developerModeEnabled = true
        let coordinatorOn = ScanPreviewCoordinator(
            presenter: UIViewController(),
            scanService: ScanService(),
            settingsStore: settingsOn,
            scanFlowState: ScanFlowState()
        )
        XCTAssertTrue(coordinatorOn.debug_addFitControlsIfDeveloperMode(hostView: hostView))
        XCTAssertTrue(coordinatorOn.debug_hasFitBrowSlider())
    }
}

private extension UIView {
    func findView(withAccessibilityIdentifier identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier { return self }
        for subview in subviews {
            if let match = subview.findView(withAccessibilityIdentifier: identifier) {
                return match
            }
        }
        return nil
    }
}
