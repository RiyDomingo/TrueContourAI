import XCTest
@testable import TrueContourAI

final class AccessibilitySmokeTests: XCTestCase {

    private func makeRepository(scansRootURL: URL? = nil) -> ScanRepository {
        ScanRepository(scansRootURL: scansRootURL ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    private func makeExporter(scansRootURL: URL? = nil) -> ScanExporterService {
        let root = scansRootURL ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return ScanExporterService(scansRootURL: root)
    }

    func testHomeButtonsHaveAccessibilityLabels() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let deps = AppDependencies(
            scanRepository: ScanRepository(scansRootURL: tempDir),
            scanExporter: makeExporter(scansRootURL: tempDir),
            settingsStore: SettingsStore(),
            earServiceFactory: { nil }
        )
        let settingsAssembler = SettingsAssembler(dependencies: deps)
        let scanAssembler = ScanAssembler(dependencies: deps)
        let previewAssembler = PreviewAssembler(dependencies: deps)
        let vc = HomeAssembler(
            dependencies: deps,
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
        let overlay = PreviewOverlayUIController()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let verifyButton = overlay.addVerifyEarUI(to: host, showHint: false)
        XCTAssertEqual(verifyButton.accessibilityLabel, L("scan.preview.accessibility.verify.label"))
        XCTAssertEqual(verifyButton.accessibilityHint, L("scan.preview.accessibility.verify.hint"))
    }

    func testPreviewVerifyButtonRemainsVisibleWithoutDeveloperMode() {
        let overlay = PreviewOverlayUIController()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        _ = overlay.addVerifyEarUI(to: host, showHint: false)
        overlay.setDeveloperModeEnabled(false)

        let verifyButton = host.findView(withAccessibilityIdentifier: "verifyEarButton")
        XCTAssertNotNil(verifyButton)
        XCTAssertFalse(verifyButton?.isHidden ?? true)
    }

    func testFitBrowSliderAppearsOnlyInDeveloperMode() {
        let hostView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))

        let defaultsOff = UserDefaults(suiteName: "FitBrowSliderOff.\(UUID().uuidString)")!
        let settingsOff = SettingsStore(defaults: defaultsOff)
        settingsOff.developerModeEnabled = false
        XCTAssertFalse(PreviewViewController.debug_addFitControlsIfDeveloperMode(hostView: hostView, settingsStore: settingsOff))
        XCTAssertNil(hostView.findSlider())

        let defaultsOn = UserDefaults(suiteName: "FitBrowSliderOn.\(UUID().uuidString)")!
        let settingsOn = SettingsStore(defaults: defaultsOn)
        settingsOn.developerModeEnabled = true
        XCTAssertTrue(PreviewViewController.debug_addFitControlsIfDeveloperMode(hostView: hostView, settingsStore: settingsOn))
        XCTAssertNotNil(hostView.findSlider())
    }

    func testPreviewSheetProfileCompactsOnSmallHeight() {
        let p = PreviewOverlayUIController.debug_sheetProfile(height: 680, isPad: false)
        XCTAssertEqual(p.collapsed, 80)
        XCTAssertEqual(p.half, 112)
        XCTAssertEqual(p.full, 144)
    }

    func testPreviewSheetStaysCollapsedWhenDeveloperModeEnabled() {
        let overlay = PreviewOverlayUIController()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        overlay.debug_installSheet(on: host)
        overlay.setDeveloperModeEnabled(true)
        XCTAssertEqual(overlay.debug_currentSnapPoint(), .collapsed)
    }

    func testPreviewSheetFrameRatioStaysWithinViewportCaps() {
        let smallPhone = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let smallFrame = PreviewOverlayUIController()
            .debug_sheetFrame(on: smallPhone, developerModeEnabled: false)
        XCTAssertLessThanOrEqual(smallFrame.height / smallPhone.bounds.height, 0.22)

        let regularPhone = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let regularFrame = PreviewOverlayUIController()
            .debug_sheetFrame(on: regularPhone, developerModeEnabled: false)
        XCTAssertLessThanOrEqual(regularFrame.height / regularPhone.bounds.height, 0.20)

        let largePad = UIView(frame: CGRect(x: 0, y: 0, width: 820, height: 1180))
        let padFrame = PreviewOverlayUIController()
            .debug_sheetFrame(on: largePad, developerModeEnabled: true)
        XCTAssertLessThanOrEqual(padFrame.height / largePad.bounds.height, 0.18)
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

    func findSlider() -> UISlider? {
        if let slider = self as? UISlider { return slider }
        for subview in subviews {
            if let slider = subview.findSlider() {
                return slider
            }
        }
        return nil
    }
}
