import XCTest

final class TrueContourAIDeviceSmokeTests: XCTestCase {
    private static let timeout: TimeInterval = 8.0

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
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

        let shutter = app.buttons["scanShutterButton"]
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                shutter.exists && shutter.isHittable
            },
            "Expected scan shutter button to become hittable on device"
        )
        shutter.tap() // start countdown -> scanning
        _ = waitUntil(timeout: 6.0) { app.buttons["finishScanNowButton"].isHittable }

        XCTAssertTrue(waitForElement(app.buttons["finishScanNowButton"], timeout: 12))
        app.buttons["finishScanNowButton"].tap()
        XCTAssertTrue(waitForElement(app.buttons["previewSaveButton"], timeout: 30))
    }

    @MainActor
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

        let shutter = app.buttons["scanShutterButton"]
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                shutter.exists && shutter.isHittable
            },
            "Expected scan shutter button to become hittable on device"
        )
        shutter.tap()

        XCTAssertTrue(waitForElement(app.buttons["scanDismissButton"], timeout: 8))
        app.buttons["scanDismissButton"].tap()
        XCTAssertTrue(waitForElement(startButton, timeout: 8))
    }

    @MainActor
    func testDeviceSmokeSaveReportsExportArtifactPresence() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(skipEarML: true)
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = app.buttons["scanShutterButton"]
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                shutter.exists && shutter.isHittable
            },
            "Expected scan shutter button to become hittable on device"
        )
        shutter.tap() // start countdown -> scanning
        _ = waitUntil(timeout: 6.0) { app.buttons["finishScanNowButton"].isHittable }

        XCTAssertTrue(waitForElement(app.buttons["finishScanNowButton"], timeout: 12))
        app.buttons["finishScanNowButton"].tap()
        XCTAssertTrue(waitForElement(app.buttons["previewSaveButton"], timeout: 30))

        let ready = waitUntil(timeout: 25) { app.buttons["previewSaveButton"].isEnabled }
        XCTAssertTrue(ready)
        app.buttons["previewSaveButton"].tap()

        XCTAssertTrue(waitForElement(startButton, timeout: 20))
        let diagnosticsLabel = app.staticTexts["deviceSmokeDiagnosticsLabel"]
        XCTAssertTrue(waitForElement(diagnosticsLabel, timeout: 8.0))
        let hasExpectedDiagnostics = waitUntil(timeout: 8.0) {
            let value = diagnosticsLabel.label
            return value.contains("gltf=") && value.contains("obj=") && value.contains("folder=")
        }
        XCTAssertTrue(hasExpectedDiagnostics, "Unexpected diagnostics label: \(diagnosticsLabel.label)")
    }

    @MainActor
    func testDeviceSmokeQualityGateBlockShowsAlert() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(skipEarML: true, extraArguments: ["ui-test-force-quality-gate-block"])
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = app.buttons["scanShutterButton"]
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                shutter.exists && shutter.isHittable
            },
            "Expected scan shutter button to become hittable on device"
        )
        shutter.tap()
        _ = waitUntil(timeout: 6.0) { app.buttons["finishScanNowButton"].isHittable }

        XCTAssertTrue(waitForElement(app.buttons["finishScanNowButton"], timeout: 12))
        app.buttons["finishScanNowButton"].tap()
        XCTAssertTrue(waitForElement(app.buttons["previewSaveButton"], timeout: 30))
        XCTAssertTrue(waitUntil(timeout: 25) { app.buttons["previewSaveButton"].isEnabled })
        app.buttons["previewSaveButton"].tap()

        let alert = app.alerts["qualityGateAlert"]
        XCTAssertTrue(waitForElement(alert, timeout: 8.0))
        alert.buttons["OK"].tap()
        XCTAssertTrue(waitForElement(app.buttons["previewSaveButton"], timeout: 4.0))
    }

    @MainActor
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

    @MainActor
    func testDeviceSmokeSaveReportsOBJOnlyArtifacts() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(
            skipEarML: true,
            extraArguments: ["ui-test-export-gltf-off"]
        )
        let diagnostics = try saveAndReturnDiagnostics(app: app)
        XCTAssertTrue(diagnostics.contains("gltf=0"), "Expected GLTF to be disabled in diagnostics: \(diagnostics)")
        XCTAssertTrue(diagnostics.contains("obj=1"), "Expected OBJ artifact in diagnostics: \(diagnostics)")
    }

    @MainActor
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

    @MainActor
    private func saveAndReturnDiagnostics(app: XCUIApplication) throws -> String {
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = app.buttons["scanShutterButton"]
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                shutter.exists && shutter.isHittable
            },
            "Expected scan shutter button to become hittable on device"
        )
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

    @MainActor
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 8.0) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval, poll: TimeInterval = 0.1, condition: @escaping () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(poll))
        }
        return condition()
    }
}
