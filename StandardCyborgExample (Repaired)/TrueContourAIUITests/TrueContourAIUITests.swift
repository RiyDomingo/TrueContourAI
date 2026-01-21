//
//  TrueContourAIUITests.swift
//  TrueContourAIUITests
//
//  Created by Riy Domingo on 2026/01/21.
//  Copyright © 2026 Standard Cyborg. All rights reserved.
//

import XCTest

final class TrueContourAIUITests: XCTestCase {

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
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testHomeShowsCoreActions() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["startScanButton"].waitForExistence(timeout: 2.0))
        XCTAssertTrue(app.buttons["howToScanButton"].waitForExistence(timeout: 2.0))
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 2.0))
    }

    @MainActor
    func testHowToSheetOpensAndCloses() throws {
        let app = launchApp()

        let howToButton = app.buttons["howToScanButton"]
        XCTAssertTrue(howToButton.exists)
        howToButton.tap()

        let closeButton = app.buttons["howToCloseButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2.0))
        closeButton.tap()
        XCTAssertFalse(closeButton.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        return app
    }
}
