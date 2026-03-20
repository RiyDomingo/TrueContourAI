import XCTest
@testable import TrueContourAI

final class SettingsStorageUseCaseTests: XCTestCase {
    func testDeleteAllScansRunsOffMainThread() {
        let service = SettingsScanServiceFake()
        let useCase = SettingsStorageUseCase(scanService: service)
        let expectation = expectation(description: "delete-all")
        var completionRanOnMainThread = false

        useCase.deleteAllScans { result in
            completionRanOnMainThread = Thread.isMainThread
            XCTAssertTrue({
                if case .success = result { return true }
                return false
            }())
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(service.deleteAllCallCount, 1)
        XCTAssertFalse(service.deleteAllExecutedOnMainThread)
        XCTAssertTrue(completionRanOnMainThread)
    }

    func testRefreshStorageUsageRunsAsyncAndReturnsResolvedText() {
        let service = SettingsScanServiceFake()
        let useCase = SettingsStorageUseCase(scanService: service)
        let expectation = expectation(description: "storage-usage")
        var resolved = L("settings.calculating")
        var completionRanOnMainThread = false

        useCase.refreshStorageUsage { text in
            completionRanOnMainThread = Thread.isMainThread
            resolved = text
            expectation.fulfill()
        }

        XCTAssertEqual(resolved, L("settings.calculating"))
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotEqual(resolved, L("settings.calculating"))
        XCTAssertTrue(completionRanOnMainThread)
    }
}
