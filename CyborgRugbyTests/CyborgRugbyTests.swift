//
//  CyborgRugbyTests.swift
//  CyborgRugbyTests
//
//  Main test suite for CyborgRugby application
//

import XCTest
@testable import CyborgRugby

final class CyborgRugbyTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testApplicationLaunch() throws {
        // Test that the app can be launched without crashing
        // This is a basic smoke test
        XCTAssertNoThrow({
            // Basic validation that key types are available
            _ = HeadScanningPose.frontFacing
            _ = ScrumCapSize.medium
        }(), "Core types should be available")
    }
    
    func testHeadScanningPoseEnumeration() throws {
        let allPoses: [HeadScanningPose] = [
            .frontFacing,
            .leftProfile,
            .rightProfile,
            .leftThreeQuarter,
            .rightThreeQuarter,
            .lookingDown,
            .chinUp
        ]
        
        XCTAssertEqual(allPoses.count, 7, "Should have exactly 7 scanning poses")
        
        // Test that all poses have valid raw values
        for pose in allPoses {
            XCTAssertFalse(pose.rawValue.isEmpty, "Each pose should have a non-empty raw value")
        }
    }
    
    func testScrumCapSizeEnumeration() throws {
        let allSizes: [ScrumCapSize] = [
            .youth,
            .small,
            .medium,
            .large,
            .extraLarge,
            .doubleXL
        ]
        
        XCTAssertEqual(allSizes.count, 6, "Should have exactly 6 size options")
        
        // Test that sizes have logical ordering
        XCTAssertTrue(ScrumCapSize.youth < ScrumCapSize.small)
        XCTAssertTrue(ScrumCapSize.small < ScrumCapSize.medium)
        XCTAssertTrue(ScrumCapSize.medium < ScrumCapSize.large)
        XCTAssertTrue(ScrumCapSize.large < ScrumCapSize.extraLarge)
        XCTAssertTrue(ScrumCapSize.extraLarge < ScrumCapSize.doubleXL)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
            for _ in 0..<1000 {
                _ = HeadScanningPose.frontFacing.rawValue
            }
        }
    }
}