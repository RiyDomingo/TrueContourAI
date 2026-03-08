import XCTest

final class TrueContourAIDeviceSmokeTests: XCTestCase {
    private static let timeout: TimeInterval = 8.0

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDeviceSmokeStartScanFinishShowsPreview() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp()
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap() // start countdown -> scanning
        _ = waitUntil(timeout: 6.0) { app.buttons["finishScanNowButton"].isHittable }

        XCTAssertTrue(waitForElement(app.buttons["finishScanNowButton"], timeout: 12))
        app.buttons["finishScanNowButton"].tap()
        XCTAssertTrue(waitForElement(app.buttons["previewSaveButton"], timeout: 30))
    }

    func testDeviceSmokeStartScanCancelReturnsHome() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp()
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap()

        XCTAssertTrue(waitForElement(app.buttons["scanDismissButton"], timeout: 8))
        app.buttons["scanDismissButton"].tap()
        XCTAssertTrue(waitForElement(startButton, timeout: 8))
    }

    func testDeviceSmokeScanHUDCountdownProgressAndControls() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp()
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap()

        let countdown = app.staticTexts["scanCountdownLabel"]
        XCTAssertTrue(waitForElement(countdown, timeout: 3.0), "Expected countdown label after starting scan")

        let progress = app.staticTexts["scanProgressLabel"]
        XCTAssertTrue(waitForElement(progress, timeout: 10.0), "Expected visible capture progress text during scan")

        let statusChip = app.staticTexts["scanGuidanceStatusChip"]
        XCTAssertTrue(
            waitUntil(timeout: 10.0) {
                statusChip.exists && !statusChip.label.isEmpty
            },
            "Expected guidance status chip during active scan"
        )

        let finish = app.buttons["finishScanNowButton"]
        XCTAssertTrue(waitForElement(finish, timeout: 12), "Expected finish button while guidance updates")
        finish.tap()
        XCTAssertTrue(waitForElement(app.buttons["previewSaveButton"], timeout: 30))
    }

    func testDeviceSmokeSaveReportsExportArtifactPresence() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(skipEarML: true)
        let diagnostics = try saveAndReturnDiagnostics(app: app)
        XCTAssertTrue(diagnostics.contains("gltf=1"), "Expected GLTF artifact in diagnostics: \(diagnostics)")
        XCTAssertTrue(diagnostics.contains("obj=1"), "Expected OBJ artifact in diagnostics: \(diagnostics)")
    }

    func testDeviceSmokeForcedQualityGateStillAllowsSave() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(skipEarML: true, extraArguments: ["ui-test-force-quality-gate-block"])
        let diagnostics = try saveAndReturnDiagnostics(app: app)
        XCTAssertTrue(diagnostics.contains("folder="), "Expected save to succeed with forced quality gate: \(diagnostics)")
        XCTAssertFalse(diagnostics.contains("folder=none"), "Expected saved folder when forced quality gate is enabled: \(diagnostics)")
    }

    func testDeviceSmokeSaveReportsGLTFOnlyArtifacts() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(
            skipEarML: true,
            extraArguments: ["ui-test-export-obj-off"]
        )
        let diagnostics = try saveAndReturnDiagnostics(app: app)
        XCTAssertTrue(diagnostics.contains("gltf=1"), "Expected GLTF artifact in diagnostics: \(diagnostics)")
        XCTAssertTrue(diagnostics.contains("obj=0"), "Expected OBJ to be disabled in diagnostics: \(diagnostics)")
    }

    func testDeviceSmokeGLTFDisableLaunchArgIsIgnored() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(
            skipEarML: true,
            extraArguments: ["ui-test-export-gltf-off"]
        )
        let diagnostics = try saveAndReturnDiagnostics(app: app)
        XCTAssertTrue(diagnostics.contains("gltf=1"), "Expected GLTF artifact even when launch arg disables it: \(diagnostics)")
    }

    func testDeviceSmokeSaveThenReopenFromHome() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(skipEarML: true)
        let diagnostics = try saveAndReturnDiagnostics(app: app)
        XCTAssertTrue(diagnostics.contains("folder="), "Expected saved scan diagnostics before reopen: \(diagnostics)")

        let recentOpenButton = app.buttons["scanOpenButton"].firstMatch
        XCTAssertTrue(waitForElement(recentOpenButton, timeout: 8.0), "Expected recent scan open button after returning home")
        XCTAssertTrue(recentOpenButton.isEnabled, "Expected recent scan open button to be enabled after saving a scan")
        revealElementIfNeeded(recentOpenButton, in: app)
        XCTAssertTrue(
            waitUntil(timeout: 8.0) {
                recentOpenButton.exists && recentOpenButton.isHittable
            },
            "Expected recent scan open button to become hittable after returning home"
        )
        recentOpenButton.tap()

        let closeButton = app.buttons["previewCloseButton"]
        let reopened = waitForElement(closeButton, timeout: 20.0)
        if !reopened {
            let missingSceneAlert = app.alerts["missingSceneAlert"]
            let missingFolderAlert = app.alerts["missingFolderAlert"]
            let previewShareButton = app.buttons["previewShareButton"]
            let debugState = [
                "recentOpen.exists=\(recentOpenButton.exists ? 1 : 0)",
                "recentOpen.enabled=\(recentOpenButton.isEnabled ? 1 : 0)",
                "recentOpen.hittable=\(recentOpenButton.isHittable ? 1 : 0)",
                "previewClose.exists=\(closeButton.exists ? 1 : 0)",
                "previewShare.exists=\(previewShareButton.exists ? 1 : 0)",
                "missingSceneAlert=\(missingSceneAlert.exists ? 1 : 0)",
                "missingFolderAlert=\(missingFolderAlert.exists ? 1 : 0)",
                "diagnostics=\(diagnostics)"
            ].joined(separator: ",")
            XCTFail("Expected reopened preview close button from Home. \(debugState)")
        }
        closeButton.tap()

        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton, timeout: 8.0), "Expected to return home after closing reopened preview")
    }

    private func launchDeviceSmokeApp(skipEarML: Bool = false, extraArguments: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-UITests", "YES", "-UIAnimationsDisabled", "YES"]
        app.launchArguments += ["ui-test-scans-root", "ui-test-reset-scans", "ui-test-device-smoke"]
        if !extraArguments.contains("ui-test-force-quality-gate-block") {
            app.launchArguments.append("ui-test-disable-quality-gate")
        }
        app.launchArguments += extraArguments
        if skipEarML {
            app.launchArguments.append("ui-test-skip-ear-ml")
        }
        app.launchEnvironment["UITESTS_DISABLE_ANIMATIONS"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: Self.timeout))
        return app
    }

    private func saveAndReturnDiagnostics(app: XCUIApplication) throws -> String {
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap()
        _ = waitUntil(timeout: 6.0) { app.buttons["finishScanNowButton"].isHittable }

        XCTAssertTrue(waitForElement(app.buttons["finishScanNowButton"], timeout: 12))
        app.buttons["finishScanNowButton"].tap()
        XCTAssertTrue(waitForElement(app.buttons["previewSaveButton"], timeout: 30))
        XCTAssertTrue(waitUntil(timeout: 25) { app.buttons["previewSaveButton"].isEnabled })
        app.buttons["previewSaveButton"].tap()

        let didReturnHome = waitUntil(timeout: 20) {
            let homeStart = app.buttons["startScanButton"]
            let previewSave = app.buttons["previewSaveButton"]
            return homeStart.exists && homeStart.isHittable && !previewSave.exists
        }
        if !didReturnHome {
            let exportAlert = app.alerts["exportFailedAlert"]
            let qualityAlert = app.alerts["qualityGateAlert"]
            let meshAlert = app.alerts["meshNotReadyAlert"]
            let saveButton = app.buttons["previewSaveButton"]
            let saveOverlay = app.otherElements["savingToastLabel"]
            let debugState = [
                "exportAlert=\(exportAlert.exists ? exportAlert.label : "none")",
                "qualityAlert=\(qualityAlert.exists ? qualityAlert.label : "none")",
                "meshAlert=\(meshAlert.exists ? meshAlert.label : "none")",
                "saveButton.exists=\(saveButton.exists ? 1 : 0)",
                "saveButton.hittable=\(saveButton.isHittable ? 1 : 0)",
                "saveButton.enabled=\(saveButton.isEnabled ? 1 : 0)",
                "savingOverlay.exists=\(saveOverlay.exists ? 1 : 0)",
                "savingOverlay.hittable=\(saveOverlay.isHittable ? 1 : 0)"
            ].joined(separator: ",")
            XCTFail("Expected to return to the home screen after save. \(debugState)")
        }
        let diagnosticsLabel = app.staticTexts["deviceSmokeDiagnosticsLabel"]
        XCTAssertTrue(
            waitUntil(timeout: 8.0) {
                diagnosticsLabel.exists && diagnosticsLabel.isHittable
            },
            "Expected visible device diagnostics label after save"
        )
        let hasExpectedDiagnostics = waitUntil(timeout: 8.0) {
            let value = diagnosticsLabel.label
            return value.contains("folder=") && !value.contains("folder=none")
        }
        XCTAssertTrue(hasExpectedDiagnostics, "Unexpected diagnostics label: \(diagnosticsLabel.label)")
        return diagnosticsLabel.label
    }

    private func waitForScanShutter(app: XCUIApplication) throws -> XCUIElement {
        let shutter = app.buttons["scanShutterButton"]
        let didBecomeHittable = waitUntil(timeout: 20) {
            if app.state != .runningForeground {
                app.activate()
            }
            return shutter.exists && shutter.isHittable
        }
        XCTAssertTrue(didBecomeHittable, "Expected scan shutter button to become hittable on device")
        return shutter
    }

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 8.0) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    private func revealElementIfNeeded(_ element: XCUIElement, in app: XCUIApplication, maxScrolls: Int = 4) {
        guard element.exists else { return }
        guard !element.isHittable else { return }

        for _ in 0..<maxScrolls where !element.isHittable {
            app.swipeUp()
        }
    }
}
