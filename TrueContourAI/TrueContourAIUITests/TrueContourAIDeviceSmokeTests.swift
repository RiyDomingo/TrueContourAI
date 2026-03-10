import XCTest

final class TrueContourAIDeviceSmokeTests: XCTestCase {
    private static let timeout: TimeInterval = 8.0
    private static let pollInterval: TimeInterval = 0.5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDeviceSmokeStartScanFinishShowsPreview() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp()
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForExists(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap() // start countdown -> scanning
        _ = waitForHittable(app.buttons["finishScanNowButton"], timeout: 6.0)

        XCTAssertTrue(waitForHittable(app.buttons["finishScanNowButton"], timeout: 12))
        app.buttons["finishScanNowButton"].tap()
        XCTAssertTrue(waitForExists(app.buttons["previewSaveButton"], timeout: 30))
    }

    func testDeviceSmokeStartScanCancelReturnsHome() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp()
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForExists(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap()

        XCTAssertTrue(waitForExists(app.buttons["scanDismissButton"], timeout: 8))
        app.buttons["scanDismissButton"].tap()
        XCTAssertTrue(waitForExists(startButton, timeout: 8))
    }

    func testDeviceSmokeScanHUDCountdownProgressAndControls() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp()
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForExists(startButton))
        startButton.tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap()

        let countdown = app.staticTexts["scanCountdownLabel"]
        XCTAssertTrue(waitForExists(countdown, timeout: 3.0), "Expected countdown label after starting scan")

        let progress = app.staticTexts["scanProgressLabel"]
        XCTAssertTrue(waitForExists(progress, timeout: 10.0), "Expected visible capture progress text during scan")

        let statusChip = app.staticTexts["scanGuidanceStatusChip"]
        XCTAssertTrue(
            waitForNonEmptyLabel(statusChip, timeout: 10.0),
            "Expected guidance status chip during active scan"
        )

        let finish = app.buttons["finishScanNowButton"]
        XCTAssertTrue(waitForHittable(finish, timeout: 12), "Expected finish button while guidance updates")
        finish.tap()
        XCTAssertTrue(waitForExists(app.buttons["previewSaveButton"], timeout: 30))
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

    func testDeviceSmokeForcedQualityGateBlocksSave() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("TrueDepth smoke tests run only on physical iPhone hardware")
#endif
        let app = launchDeviceSmokeApp(skipEarML: true, extraArguments: ["ui-test-force-quality-gate-block"])
        XCTAssertTrue(waitForExists(app.buttons["startScanButton"]))
        app.buttons["startScanButton"].tap()

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap()
        let finishButton = try waitForFinishButton(app: app)
        finishButton.tap()
        XCTAssertTrue(waitForExists(app.buttons["previewSaveButton"], timeout: 30))
        XCTAssertTrue(waitForEnabled(app.buttons["previewSaveButton"], timeout: 25))
        app.buttons["previewSaveButton"].tap()

        let qualityAlert = app.alerts["qualityGateAlert"]
        XCTAssertTrue(waitForExists(qualityAlert, timeout: 10.0), "Expected quality gate alert when forced quality gate is enabled")
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
        XCTAssertTrue(waitForExists(recentOpenButton, timeout: 8.0), "Expected recent scan open button after returning home")
        XCTAssertTrue(recentOpenButton.isEnabled, "Expected recent scan open button to be enabled after saving a scan")
        revealElementIfNeeded(recentOpenButton, in: app)
        XCTAssertTrue(waitForHittable(recentOpenButton, timeout: 8.0), "Expected recent scan open button to become hittable after returning home")
        recentOpenButton.tap()

        let closeButton = app.buttons["previewCloseButton"]
        let reopened = waitForExists(closeButton, timeout: 20.0)
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
        XCTAssertTrue(waitForExists(startButton, timeout: 8.0), "Expected to return home after closing reopened preview")
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
        XCTAssertTrue(waitForExists(startButton))
        startButton.tap()

        advancePastChecklistIfNeeded(in: app)

        if app.alerts["TrueDepth Not Available"].waitForExistence(timeout: 2.0) {
            throw XCTSkip("Connected device does not expose TrueDepth camera")
        }

        let shutter = try waitForScanShutter(app: app)
        shutter.tap()
        let finishButton = try waitForFinishButton(app: app)
        finishButton.tap()
        let saveButton = app.buttons["previewSaveButton"]
        XCTAssertTrue(waitForExists(saveButton, timeout: 30), "Expected preview save button to appear")
        revealElementIfNeeded(saveButton, in: app)
        XCTAssertTrue(waitForHittable(saveButton, timeout: 4), "Expected preview save button to become hittable")
        saveButton.tap()

        let homeStart = app.buttons["startScanButton"]
        let didReturnHome = waitForCondition(timeout: 30.0) {
            homeStart.exists
                && homeStart.isHittable
                && !saveButton.exists
        }
        if !didReturnHome {
            let exportAlert = app.alerts["exportFailedAlert"]
            let qualityAlert = app.alerts["qualityGateAlert"]
            let meshAlert = app.alerts["meshNotReadyAlert"]
            let previewClose = app.buttons["previewCloseButton"]
            let debugState = [
                "exportAlert=\(exportAlert.exists ? exportAlert.label : "none")",
                "qualityAlert=\(qualityAlert.exists ? qualityAlert.label : "none")",
                "meshAlert=\(meshAlert.exists ? meshAlert.label : "none")",
                "homeStart.exists=\(homeStart.exists ? 1 : 0)",
                "homeStart.hittable=\(homeStart.isHittable ? 1 : 0)",
                "saveButton.exists=\(saveButton.exists ? 1 : 0)",
                "saveButton.hittable=\(saveButton.isHittable ? 1 : 0)",
                "saveButton.enabled=\(saveButton.isEnabled ? 1 : 0)",
                "previewClose.exists=\(previewClose.exists ? 1 : 0)",
                "app.state=\(app.state.rawValue)"
            ].joined(separator: ",")
            XCTFail("Expected to return to the home screen after save. \(debugState)")
        }
        let diagnosticsLabel = app.staticTexts["deviceSmokeDiagnosticsLabel"]
        XCTAssertTrue(waitForExists(diagnosticsLabel, timeout: 12.0), "Expected visible device diagnostics label after save")
        let hasExpectedDiagnostics = waitForCondition(timeout: 12.0) {
            diagnosticsLabel.exists
                && diagnosticsLabel.label.contains("folder=")
                && !diagnosticsLabel.label.contains("folder=none")
        }
        XCTAssertTrue(hasExpectedDiagnostics, "Unexpected diagnostics label: \(diagnosticsLabel.label)")
        return diagnosticsLabel.label
    }

    private func waitForScanShutter(app: XCUIApplication) throws -> XCUIElement {
        let shutter = app.buttons["scanShutterButton"]
        if app.state != .runningForeground {
            app.activate()
        }

        advancePastChecklistIfNeeded(in: app)

        if dismissTrueDepthAlertIfPresent(in: app) {
            let startScanButton = app.buttons["startScanButton"]
            if waitForExists(startScanButton, timeout: 2.0) {
                revealElementIfNeeded(startScanButton, in: app)
                if waitForHittable(startScanButton, timeout: 2.0) {
                    startScanButton.tap()
                    advancePastChecklistIfNeeded(in: app)
                }
            }
        }

        let didAppear = waitForExists(shutter, timeout: 12.0)
        if !didAppear {
            if app.state != .runningForeground {
                app.activate()
            }
            advancePastChecklistIfNeeded(in: app)
            _ = dismissTrueDepthAlertIfPresent(in: app)
        }

        XCTAssertTrue(didAppear || waitForExists(shutter, timeout: 4.0), "Expected scan shutter button to appear on device. \(scanEntryDebugState(app: app, shutter: shutter))")

        revealElementIfNeeded(shutter, in: app)
        let didBecomeReady = shutter.isHittable || waitForHittable(shutter, timeout: 6.0)
        XCTAssertTrue(didBecomeReady, "Expected scan shutter button to become hittable on device. \(scanEntryDebugState(app: app, shutter: shutter))")
        return shutter
    }

    private func waitForFinishButton(app: XCUIApplication) throws -> XCUIElement {
        let finishButton = app.buttons["finishScanNowButton"]
        let progressLabel = app.staticTexts["scanProgressLabel"]
        let countdownLabel = app.staticTexts["scanCountdownLabel"]

        let didReachScanningUI = waitForExists(progressLabel, timeout: 8.0)
            || waitForExists(countdownLabel, timeout: 3.0)
            || waitForExists(finishButton, timeout: 8.0)
        XCTAssertTrue(
            didReachScanningUI,
            "Expected countdown, progress, or finish control after starting scan. progressExists=\(progressLabel.exists ? 1 : 0),countdownExists=\(countdownLabel.exists ? 1 : 0),finishExists=\(finishButton.exists ? 1 : 0)"
        )

        XCTAssertTrue(waitForExists(finishButton, timeout: 12), "Expected finish button after scan starts")
        revealElementIfNeeded(finishButton, in: app)
        if app.state != .runningForeground {
            app.activate()
        }
        XCTAssertTrue(waitForEnabled(finishButton, timeout: 8), "Expected finish button to become enabled during device smoke flow")
        revealElementIfNeeded(finishButton, in: app)
        XCTAssertTrue(waitForHittable(finishButton, timeout: 4), "Expected finish button to become hittable during device smoke flow")
        return finishButton
    }

    private func waitForExists(_ element: XCUIElement, timeout: TimeInterval = 8.0) -> Bool {
        waitForCondition(timeout: timeout) {
            element.exists
        }
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitForCondition(timeout: timeout) {
            element.exists && element.isHittable
        }
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitForCondition(timeout: timeout) {
            element.exists && element.isEnabled
        }
    }

    private func waitForValue(_ element: XCUIElement, equals expectedValue: String, timeout: TimeInterval) -> Bool {
        waitForCondition(timeout: timeout) {
            guard element.exists else { return false }
            return (element.value as? String) == expectedValue
        }
    }

    private func waitForNotExists(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitForCondition(timeout: timeout) {
            !element.exists
        }
    }

    private func waitForLabelContains(_ element: XCUIElement, _ substring: String, timeout: TimeInterval) -> Bool {
        waitForCondition(timeout: timeout) {
            element.exists && element.label.contains(substring)
        }
    }

    private func waitForNonEmptyLabel(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitForCondition(timeout: timeout) {
            element.exists && !element.label.isEmpty
        }
    }

    private func dismissTrueDepthAlertIfPresent(in app: XCUIApplication) -> Bool {
        let alert = app.alerts["TrueDepth Not Available"]
        guard alert.exists || alert.waitForExistence(timeout: 0.5) else { return false }
        let dismissButton = alert.buttons.firstMatch
        if dismissButton.exists {
            dismissButton.tap()
        }
        return true
    }

    private func advancePastChecklistIfNeeded(in app: XCUIApplication) {
        let checklistStartButton = app.buttons["preScanChecklistStartButton"]
        guard checklistStartButton.exists || checklistStartButton.waitForExistence(timeout: 0.5) else { return }

        let checklistSwitchLabels = [
            "Good lighting (avoid glare)",
            "Hair clear of ears / forehead",
            "Head still — move phone around"
        ]
        for label in checklistSwitchLabels {
            let toggle = app.switches[label]
            guard toggle.exists || toggle.waitForExistence(timeout: 0.25) else { continue }
            if String(describing: toggle.value) == "0" {
                toggle.tap()
            }
        }

        revealElementIfNeeded(checklistStartButton, in: app)
        if waitForHittable(checklistStartButton, timeout: 2.0) {
            checklistStartButton.tap()
        }
    }

    private func waitForPredicate(_ format: String, element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: format)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForPredicate(_ format: String, argument: String, element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: format, argument)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForCondition(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            Thread.sleep(forTimeInterval: Self.pollInterval)
        }
        return condition()
    }

    private func scanEntryDebugState(app: XCUIApplication, shutter: XCUIElement) -> String {
        let alert = app.alerts["TrueDepth Not Available"]
        let checklistStartButton = app.buttons["preScanChecklistStartButton"]
        let startButton = app.buttons["startScanButton"]
        return [
            "app.state=\(app.state.rawValue)",
            "alert.exists=\(alert.exists ? 1 : 0)",
            "checklist.exists=\(checklistStartButton.exists ? 1 : 0)",
            "start.exists=\(startButton.exists ? 1 : 0)",
            "start.hittable=\(startButton.isHittable ? 1 : 0)",
            "shutter.exists=\(shutter.exists ? 1 : 0)",
            "shutter.hittable=\(shutter.isHittable ? 1 : 0)"
        ].joined(separator: ",")
    }

    private func pollUntil(timeout: TimeInterval, poll: TimeInterval = 0.5, condition: @escaping () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            Thread.sleep(forTimeInterval: poll)
        }
        return condition()
    }

    private func revealElementIfNeeded(_ element: XCUIElement, in app: XCUIApplication, maxScrolls: Int = 4) {
        guard element.exists else { return }
        guard !element.isHittable else { return }

        for _ in 0..<maxScrolls where !element.isHittable {
            app.swipeUp()
        }
    }
}
