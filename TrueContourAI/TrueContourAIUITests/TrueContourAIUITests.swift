//
//  TrueContourAIUITests.swift
//  TrueContourAIUITests
//
//  Created by Riy Domingo on 2026/01/21.
//  Copyright © 2026 Standard Cyborg. All rights reserved.
//

import XCTest

final class TrueContourAIUITests: XCTestCase {
    private static let defaultTimeout: TimeInterval = 4.0
    private static let shortTimeout: TimeInterval = 2.0

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testHomeShowsCoreActions() throws {
        let app = launchApp()
        XCTAssertTrue(waitForElement(app.buttons["startScanButton"]))
        XCTAssertTrue(waitForElement(app.buttons["howToScanButton"]))
        XCTAssertTrue(waitForElement(app.buttons["settingsButton"]))
    }

    @MainActor
    func testHowToSheetOpensAndCloses() throws {
        let app = launchApp()

        let howToButton = app.buttons["howToScanButton"]
        XCTAssertTrue(waitForElement(howToButton))
        howToButton.tap()

        let closeButton = app.buttons["howToCloseButton"]
        XCTAssertTrue(waitForElement(closeButton))
        closeButton.tap()
        XCTAssertTrue(waitForNotExists(closeButton))
    }

    @MainActor
    func testSettingsShowsAdvancedSection() throws {
        let app = launchApp()
        openSettings(in: app)

        XCTAssertTrue(waitForElement(app.staticTexts["Advanced"]))
        XCTAssertTrue(waitForElement(app.staticTexts["Enable quality gate"]))
        XCTAssertTrue(waitForElement(app.staticTexts["Minimum quality score"]))
        XCTAssertTrue(waitForElement(app.staticTexts["Minimum valid points"]))
    }

    @MainActor
    func testSettingsQualityGateToggleIsInteractive() throws {
        let app = launchApp()
        openSettings(in: app)

        let toggle = app.switches["settings.qualityGateEnabled"]
        XCTAssertTrue(waitForElement(toggle))
        scrollElementIntoView(toggle, in: app.tables.firstMatch)
        let initial = (toggle.value as? String) ?? "0"
        if toggle.isHittable {
            toggle.tap()
        } else {
            app.cells.containing(.switch, identifier: "settings.qualityGateEnabled").firstMatch.tap()
        }
        let updated = (toggle.value as? String) ?? "0"
        XCTAssertNotEqual(initial, updated)
    }

    @MainActor
    func testSettingsMinimumQualityScoreOptionCanBeChanged() throws {
        let app = launchApp()
        openSettings(in: app)

        tapSettingsRow(named: "Minimum quality score", in: app)

        let option = settingsOptionButton(prefix: "0.75 (Strict)", in: app)
        XCTAssertTrue(waitForElement(option))
        option.tap()

        XCTAssertTrue(waitForSettingsRowValue(title: "Minimum quality score", expectedValue: "0.75 (Strict)", in: app))
    }

    @MainActor
    func testSettingsResetRestoresProcessingDefaults() throws {
        let app = launchApp()
        openSettings(in: app)

        tapSettingsRow(named: "Minimum quality score", in: app)

        let option = settingsOptionButton(prefix: "0.75 (Strict)", in: app)
        XCTAssertTrue(waitForElement(option))
        option.tap()
        XCTAssertTrue(waitForSettingsRowValue(title: "Minimum quality score", expectedValue: "0.75 (Strict)", in: app))

        tapSettingsRow(identifier: "settings.resetRow", named: "Reset settings", in: app)
        XCTAssertTrue(waitForElement(app.alerts["Reset Settings?"]))
        app.alerts["Reset Settings?"].buttons["Reset"].tap()

        XCTAssertTrue(waitForSettingsRowValue(title: "Minimum quality score", expectedValue: "0.65 (Balanced)", in: app))
    }

    @MainActor
    func testStartScanUnavailableShowsAlert() throws {
        let app = launchApp(seedScan: false, forceUnavailableTrueDepth: true)
        let startButton = app.buttons["startScanButton"]
        XCTAssertTrue(waitForElement(startButton))
        startButton.tap()

        let checklistStartButton = app.buttons["preScanChecklistStartButton"]
        if checklistStartButton.waitForExistence(timeout: 2.0) {
            app.switches["Good lighting (avoid glare)"].tap()
            app.switches["Hair clear of ears / forehead"].tap()
            app.switches["Head still — move phone around"].tap()
            XCTAssertTrue(waitForElement(checklistStartButton, timeout: 4.0))
            checklistStartButton.tap()
        }

        let alert = app.alerts["TrueDepth Not Available"]
        XCTAssertTrue(
            waitForElement(alert, timeout: 8.0),
            "Expected unavailable TrueDepth alert after forcing unsupported hardware mode"
        )
        alert.buttons["OK"].tap()
    }

    @MainActor
    func testSettingsDeleteAllConfirmationAppearsAndCancels() throws {
        let app = launchApp(seedScan: true)
        openSettings(in: app)

        tapSettingsRow(identifier: "settings.deleteAllRow", named: "Delete all scans", in: app)
        let alert = app.alerts["Delete All Scans?"]
        XCTAssertTrue(waitForElement(alert))
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(waitForNotExists(alert))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
        }
    }

    @MainActor
    func testRecentScanPreviewHasCloseButton() throws {
        let app = launchApp(seedScan: true)

        openFirstScan(in: app)

        let closeButton = app.buttons["previewCloseButton"]
        XCTAssertTrue(waitForElement(closeButton))
        closeButton.tap()

        XCTAssertTrue(waitForElement(app.buttons["startScanButton"], timeout: Self.defaultTimeout + 4.0))
    }

    @MainActor
    func testMissingSceneShowsAlert() throws {
        let app = launchApp(seedScan: false, seedMissingScene: true)

        openFirstScan(in: app)

        let alert = app.alerts["missingSceneAlert"]
        XCTAssertTrue(waitForElement(alert))
        alert.buttons.firstMatch.tap()
    }

    @MainActor
    func testMissingFolderShowsAlert() throws {
        let app = launchApp(seedScan: true, seedMissingScene: false, forceMissingFolder: true)

        openFirstScan(in: app)

        let shareButton = app.buttons["previewShareButton"]
        XCTAssertTrue(waitForElement(shareButton))
        shareButton.tap()

        let alert = app.alerts["missingFolderAlert"]
        XCTAssertTrue(waitForElement(alert))
        alert.buttons.firstMatch.tap()
    }

    @MainActor
    func testFilteredEmptyStateClearFilterRestoresScans() throws {
        let app = launchApp(seedScan: true)

        let filterControl = app.segmentedControls["recentScansFilterControl"]
        XCTAssertTrue(waitForElement(filterControl))

        let goodPlus = filterControl.buttons["Good+"]
        XCTAssertTrue(waitForElement(goodPlus))
        goodPlus.tap()

        let clearButton = app.buttons["emptyClearFilterButton"]
        XCTAssertTrue(waitForElement(clearButton))
        clearButton.tap()

        XCTAssertTrue(waitForNotExists(clearButton))
        XCTAssertTrue(waitForElement(app.buttons["scanOpenButton"].firstMatch))
    }

    @MainActor
    func testRecentScansSortControlCanSwitchToQuality() throws {
        let app = launchApp(seedScan: true)
        let sortControl = app.segmentedControls["recentScansSortControl"]
        XCTAssertTrue(waitForElement(sortControl))

        let qualityButton = sortControl.buttons["Quality"]
        XCTAssertTrue(waitForElement(qualityButton))
        qualityButton.tap()
        XCTAssertTrue(qualityButton.isSelected || (sortControl.value as? String)?.contains("Quality") == true)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        return launchApp(seedScan: false)
    }

    @MainActor
    private func launchApp(
        seedScan: Bool,
        seedMissingScene: Bool = false,
        forceMissingFolder: Bool = false,
        forceUnavailableTrueDepth: Bool = false
    ) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-UITests", "YES", "-UIAnimationsDisabled", "YES"]
        app.launchArguments += ["ui-test-scans-root", "ui-test-reset-scans"]
        app.launchEnvironment["UITESTS_DISABLE_ANIMATIONS"] = "1"
        if seedScan {
            app.launchArguments.append("ui-test-seed-scan")
            app.launchArguments.append("ui-test-skip-gltf")
        }
        if seedMissingScene {
            app.launchArguments.append("ui-test-seed-missing-scene")
        }
        if forceMissingFolder {
            app.launchArguments.append("ui-test-force-missing-folder")
        }
        if forceUnavailableTrueDepth {
            app.launchArguments.append("ui-test-force-unavailable-truedepth")
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: Self.defaultTimeout))
        return app
    }

    @MainActor
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = defaultTimeout) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    @MainActor
    private func waitForNotExists(_ element: XCUIElement, timeout: TimeInterval = defaultTimeout) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while element.exists && Date() < end {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return !element.exists
    }

    @MainActor
    private func openFirstScan(in app: XCUIApplication) {
        let table = app.tables.firstMatch
        if table.exists {
            table.scrollToTop()
        }
        let openButton = app.buttons["scanOpenButton"].firstMatch
        XCTAssertTrue(waitForElement(openButton, timeout: Self.defaultTimeout + 2))
        openButton.tap()
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(waitForElement(settingsButton))
        settingsButton.tap()
        XCTAssertTrue(waitForElement(app.navigationBars.firstMatch))
        let table = app.tables["settingsTableView"]
        XCTAssertTrue(waitForElement(table))
        let anchor = app.switches["settings.showPreScanChecklist"]
        XCTAssertTrue(
            waitUntil(timeout: 6.0) { anchor.exists },
            "Settings table did not stabilize. tableExists=\(table.exists) anchorExists=\(anchor.exists)"
        )
    }

    @MainActor
    private func tapSettingsRow(identifier: String? = nil, named title: String, in app: XCUIApplication) {
        let table = app.tables["settingsTableView"]
        XCTAssertTrue(waitForElement(table))
        let anchor = app.switches["settings.showPreScanChecklist"]
        XCTAssertTrue(waitUntil(timeout: 4.0) { anchor.exists }, "Storage anchor row was not visible before lookup")

        func currentTarget() -> XCUIElement {
            if let identifier {
                let row = table.cells[identifier]
                if row.exists { return row }
            }
            let rowCell = table.cells.containing(.staticText, identifier: title).firstMatch
            if rowCell.exists { return rowCell }
            return table.staticTexts[title]
        }

        let found = waitUntil(timeout: 6.0, poll: 0.15) {
            let target = currentTarget()
            if target.exists { return true }
            table.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            if currentTarget().exists { return true }
            table.swipeDown()
            return currentTarget().exists
        }

        let target = currentTarget()
        XCTAssertTrue(
            found && target.exists,
            "Failed to find settings row. identifier=\(identifier ?? "nil") title=\(title) tableExists=\(table.exists) anchorExists=\(anchor.exists) byIdentifier=\(identifier.map { table.cells[$0].exists } ?? false) byText=\(table.staticTexts[title].exists)"
        )
        scrollElementIntoView(target, in: table)
        XCTAssertTrue(
            waitUntil(timeout: 2.0) {
                let refreshed = currentTarget()
                return refreshed.exists && refreshed.isHittable
            },
            "Settings row never became hittable. identifier=\(identifier ?? "nil") title=\(title)"
        )
        currentTarget().tap()
    }

    @MainActor
    private func waitForSettingsRowValue(title: String, expectedValue: String, in app: XCUIApplication) -> Bool {
        let table = app.tables["settingsTableView"]
        guard waitForElement(table) else { return false }

        return waitUntil(timeout: 4.0, poll: 0.15) {
            let row = table.cells.containing(.staticText, identifier: title).firstMatch
            guard row.exists else { return false }
            if row.staticTexts[expectedValue].exists { return true }

            let label = row.label
            if label.contains(title), label.contains(expectedValue) { return true }

            let value = (row.value as? String) ?? ""
            return value.contains(expectedValue)
        }
    }

    @MainActor
    private func settingsOptionButton(prefix: String, in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        return app.buttons.matching(predicate).firstMatch
    }

    @MainActor
    private func scrollElementIntoView(_ element: XCUIElement, in table: XCUIElement, maxSwipes: Int = 8) {
        guard table.exists else { return }
        var remaining = maxSwipes
        while element.exists && !element.isHittable && remaining > 0 {
            table.swipeUp()
            remaining -= 1
        }
        remaining = maxSwipes
        while element.exists && !element.isHittable && remaining > 0 {
            table.swipeDown()
            remaining -= 1
        }
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

private extension XCUIElement {
    func scrollToTop(maxSwipes: Int = 5) {
        guard exists else { return }
        var remaining = maxSwipes
        while remaining > 0 {
            swipeDown()
            remaining -= 1
        }
    }
}
