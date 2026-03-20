import XCTest
import UIKit
import StandardCyborgFusion
@testable import TrueContourAI

final class PreviewStoreTests: XCTestCase {
    func testPreviewSessionStateTracksCurrentPreviewedFolder() {
        let state = PreviewSessionState()
        let folderURL = URL(fileURLWithPath: "/tmp/scan")

        state.currentPreviewedFolderURL = folderURL

        XCTAssertEqual(state.currentPreviewedFolderURL, folderURL)
    }

    func testBeginningPreviewSessionRotatesSessionIdentifierAndResetsArtifacts() {
        let store = PreviewStore()
        let firstSessionID = store.beginExistingScanSession()
        store.setMeasurementSummary(
            .init(
                sliceHeightNormalized: 0.62,
                circumferenceMm: 560,
                widthMm: 150,
                depthMm: 190,
                confidence: 0.7,
                status: "heuristic"
            )
        )

        let secondSessionID = store.beginPreviewSession(sessionMetrics: nil)

        XCTAssertNotEqual(firstSessionID, secondSessionID)
        XCTAssertTrue(store.isCurrentSession(secondSessionID))
        XCTAssertNil(store.measurementSummary)
    }

    func testVerificationRequiresAllArtifacts() {
        let store = PreviewStore()
        XCTAssertFalse(store.hasVerifiedEar)

        store.setVerifiedEar(
            image: UIImage(),
            result: EarLandmarksResult(
                confidence: 0.9,
                earBoundingBox: .init(x: 0, y: 0, w: 1, h: 1),
                landmarks: [],
                usedLeftEarMirroringHeuristic: false
            ),
            overlay: UIImage(),
            cropOverlay: UIImage()
        )
        XCTAssertTrue(store.hasVerifiedEar)

        store.clearVerification()
        XCTAssertFalse(store.hasVerifiedEar)
    }

    func testPhaseChanges() {
        let store = PreviewStore()
        let sessionID = store.sessionID
        XCTAssertEqual(store.phase, .preview)
        store.setPhase(.saving)
        XCTAssertEqual(store.phase, .saving)
        store.setPhase(.idle)
        XCTAssertEqual(store.phase, .idle)
        store.invalidateSession()
        XCTAssertFalse(store.isCurrentSession(sessionID))
    }

    func testEvaluateScanQualityThresholds() {
        let store = PreviewStore()

        let low = store.evaluateScanQuality(pointCount: 50_000)
        XCTAssertEqual(low.title, L("scan.preview.quality.tryagain"))

        let ok = store.evaluateScanQuality(pointCount: 120_000)
        XCTAssertEqual(ok.title, L("scan.preview.quality.ok"))

        let great = store.evaluateScanQuality(pointCount: 220_000)
        XCTAssertEqual(great.title, L("scan.preview.quality.great"))
    }

    func testFitCompletionSuccessEmitsToastAndKeepsPreviewReady() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        let fitResult = PreviewFitResult(
            summaryText: "fit summary",
            fitCheckResult: nil,
            meshDataAvailable: true
        )

        store.send(.fitCompleted(.success(fitResult)))

        if case .ready(let viewData) = store.state {
            XCTAssertEqual(viewData.measurementSummaryText, "fit summary")
        } else {
            XCTFail("Expected ready state after fit success")
        }
        if case .toast(let message)? = effects.first {
            XCTAssertEqual(message, "fit summary")
        } else {
            XCTFail("Expected fit success toast")
        }
    }

    func testFitCompletionFailureEmitsAlert() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.fitCompleted(.failure(.fitFailed("fit failed"))))

        if case .alert(let title, let message, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.fit.unavailable.title"))
            XCTAssertEqual(message, "fit failed")
            XCTAssertEqual(identifier, "fitUnavailableAlert")
        } else {
            XCTFail("Expected fit failure alert")
        }
    }

    func testEarVerificationSuccessSetsVerifiedStateAndEmitsAlert() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        let verification = PreviewEarVerificationResult(
            earImage: UIImage(),
            earResult: EarLandmarksResult(
                confidence: 0.9,
                earBoundingBox: .init(x: 0, y: 0, w: 1, h: 1),
                landmarks: [],
                usedLeftEarMirroringHeuristic: false
            ),
            earOverlay: UIImage(),
            earCropOverlay: UIImage()
        )

        store.send(.earVerificationCompleted(.success(verification)))

        XCTAssertTrue(store.hasVerifiedEar)
        if case .alert(let title, _, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.verified.alert.title"))
            XCTAssertEqual(identifier, "earVerifiedAlert")
        } else {
            XCTFail("Expected ear verification success alert")
        }
    }

    func testEarVerificationFailureEmitsAlert() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.earVerificationCompleted(.failure(.verificationFailed("verify failed"))))

        if case .alert(let title, let message, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.verifyFailed.title"))
            XCTAssertEqual(message, "verify failed")
            XCTAssertEqual(identifier, "earVerifyFailedAlert")
        } else {
            XCTFail("Expected ear verification failure alert")
        }
    }

    func testExistingScanLoadFailureEmitsMissingSceneAlertThenDismissRoute() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.existingScanLoadFailed(.loadFailed(L("scan.preview.missingScene.message"))))

        if case .alertThenRoute(let title, let message, let identifier, let route)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.missingScene.title"))
            XCTAssertEqual(message, L("scan.preview.missingScene.message"))
            XCTAssertEqual(identifier, "missingSceneAlert")
            if case .dismiss = route {
            } else {
                XCTFail("Expected dismiss route")
            }
        } else {
            XCTFail("Expected missing-scene alert-then-dismiss effect")
        }
    }

    func testMeshingTimeoutEmitsMeshTimeoutAlertWhenMeshUnavailable() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.postScanLoaded(makePreviewInput()))
        store.send(.meshingTimedOut)

        if case .alert(let title, _, let identifier)? = effects.last {
            XCTAssertEqual(title, L("scan.preview.meshNotReady.title"))
            XCTAssertEqual(identifier, "meshTimeoutAlert")
        } else {
            XCTFail("Expected mesh-timeout alert")
        }
    }

    func testSaveBlockedByQualityGateEmitsAlertAndReturnsReady() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.saveBlocked(.qualityGateBlocked(reason: "low quality", advice: "rescan")))

        if case .ready = store.state {
        } else {
            XCTFail("Expected ready state after blocked save")
        }
        if case .alert(let title, let message, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.quality.gate.title"))
            XCTAssertEqual(message, String(format: L("scan.quality.gate.message"), "low quality", "rescan"))
            XCTAssertEqual(identifier, "qualityGateAlert")
        } else {
            XCTFail("Expected quality-gate alert")
        }
    }

    func testSaveBlockedByMeshNotReadyEmitsAlertAndReturnsReady() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.saveBlocked(.meshNotReady))

        if case .ready = store.state {
        } else {
            XCTFail("Expected ready state after mesh-not-ready block")
        }
        if case .alert(let title, let message, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.meshNotReady.title"))
            XCTAssertEqual(message, L("scan.preview.meshNotReady.message"))
            XCTAssertEqual(identifier, "meshNotReadyAlert")
        } else {
            XCTFail("Expected mesh-not-ready alert")
        }
    }

    func testSaveBlockedByGLTFRequirementEmitsAlertAndReturnsReady() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.saveBlocked(.gltfRequired))

        if case .ready = store.state {
        } else {
            XCTFail("Expected ready state after GLTF-required block")
        }
        if case .alert(let title, let message, let identifier)? = effects.first {
            XCTAssertEqual(title, L("settings.export.minimum.title"))
            XCTAssertEqual(message, L("settings.export.minimum.message"))
            XCTAssertEqual(identifier, "exportFormatsDisabledAlert")
        } else {
            XCTFail("Expected GLTF-required alert")
        }
    }

    func testSaveBlockedByExportUnavailableEmitsAlertAndReturnsReady() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.saveBlocked(.exportUnavailable))

        if case .ready = store.state {
        } else {
            XCTFail("Expected ready state after export-unavailable block")
        }
        if case .alert(let title, let message, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.exportFailed.title"))
            XCTAssertEqual(message, String(format: L("scan.preview.exportFailed.message"), L("scan.preview.exportUnavailable.message")))
            XCTAssertEqual(identifier, "exportUnavailableAlert")
        } else {
            XCTFail("Expected export-unavailable alert")
        }
    }

    func testSaveInvocationFailureEmitsExportInvocationAlertAndReturnsReady() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.saveInvocationFailed("export unavailable"))

        if case .ready = store.state {
        } else {
            XCTFail("Expected ready state after invocation failure")
        }
        if case .alert(let title, _, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.exportFailed.title"))
            XCTAssertEqual(identifier, "exportInvocationAlert")
        } else {
            XCTFail("Expected export invocation alert")
        }
    }

    func testSaveTappedTransitionsToSavingStateWithDisabledActions() {
        let store = PreviewStore()

        store.send(.saveTapped)

        guard case .saving(let viewData) = store.state else {
            return XCTFail("Expected saving state")
        }
        XCTAssertEqual(viewData.meshingStatusText, L("scan.preview.exporting"))
        XCTAssertTrue(viewData.meshingSpinnerVisible)
        XCTAssertFalse(viewData.saveButtonEnabled)
        XCTAssertFalse(viewData.shareButtonEnabled)
        XCTAssertFalse(viewData.verifyEarButtonEnabled)
    }

    func testPostScanLoadedTransitionsToMeshingState() {
        let store = PreviewStore()

        store.send(.postScanLoaded(makePreviewInput()))

        guard case .meshing(let viewData) = store.state else {
            return XCTFail("Expected meshing state after post-scan load")
        }
        XCTAssertEqual(viewData.meshingStatusText, L("scan.preview.meshing"))
        XCTAssertTrue(viewData.meshingSpinnerVisible)
    }

    func testSaveBecomesEnabledOnlyAfterMeshingCompletesAndMeshIsAvailable() {
        let store = PreviewStore()

        store.send(.postScanLoaded(makePreviewInput()))

        guard case .meshing(let initial) = store.state else {
            return XCTFail("Expected meshing state after post-scan load")
        }
        XCTAssertFalse(initial.saveButtonEnabled)

        store.setMeshForExport(makeMeshPlaceholder())
        guard case .meshing(let stillMeshing) = store.state else {
            return XCTFail("Expected meshing state while meshing remains active")
        }
        XCTAssertFalse(stillMeshing.saveButtonEnabled)

        store.setMeshingActive(false)
        guard case .ready(let ready) = store.state else {
            return XCTFail("Expected ready state after meshing completes")
        }
        XCTAssertTrue(ready.saveButtonEnabled)
        XCTAssertEqual(ready.meshingStatusText, L("scan.preview.readyToSave"))
    }

    func testSavingStateRetainsFitSummaryAndVerifiedEarStatus() {
        let store = PreviewStore()
        store.setFitResult(
            .init(
                summaryText: "fit summary",
                fitCheckResult: nil,
                meshDataAvailable: true
            )
        )
        store.setVerifiedEar(
            image: UIImage(),
            result: EarLandmarksResult(
                confidence: 0.9,
                earBoundingBox: .init(x: 0, y: 0, w: 1, h: 1),
                landmarks: [],
                usedLeftEarMirroringHeuristic: false
            ),
            overlay: UIImage(),
            cropOverlay: UIImage()
        )
        store.setMeshForExport(makeMeshPlaceholder())
        store.setMeshingActive(false)

        store.send(.saveTapped)

        guard case .saving(let viewData) = store.state else {
            return XCTFail("Expected saving state")
        }
        XCTAssertEqual(viewData.measurementSummaryText, "fit summary")
        XCTAssertTrue(viewData.earVerified)
        XCTAssertFalse(viewData.saveButtonEnabled)
        XCTAssertFalse(viewData.verifyEarButtonEnabled)
    }

    func testNoEarVerificationFailureUsesNoEarAlert() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.send(.earVerificationCompleted(.failure(.verificationFailed(L("scan.preview.noEar.message")))))

        if case .alert(let title, let message, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.noEar.title"))
            XCTAssertEqual(message, L("scan.preview.noEar.message"))
            XCTAssertEqual(identifier, "noEarAlert")
        } else {
            XCTFail("Expected no-ear alert")
        }
    }

    func testEarVerificationRequestPrefersPreservedBestCaptureFrameMetadata() {
        let store = PreviewStore()
        let preserved = UIImage()
        _ = store.beginPreviewSession(
            sessionMetrics: nil,
            preservedEarVerificationImage: preserved,
            preservedEarVerificationSelectionMetadata: EarVerificationSelectionMetadata(
                source: .bestCaptureFrame,
                frameIndex: 4,
                totalScore: 0.9,
                profileScore: 0.8,
                trackingScore: 0.7,
                guidanceScore: 0.6,
                timingScore: 0.5
            )
        )

        let request = store.makeEarVerificationRequest(previewSnapshot: UIImage())

        XCTAssertTrue(request.verificationImage === preserved)
        XCTAssertEqual(request.source, .bestCaptureFrame)
        XCTAssertEqual(request.selectionMetadata?.frameIndex, 4)
    }

    func testPresentFitExportFailureEmitsFitExportAlert() {
        let store = PreviewStore()
        var effects: [PreviewEffect] = []
        store.onEffect = { effects.append($0) }

        store.presentFitExportFailure(message: "disk full")

        if case .alert(let title, let message, let identifier)? = effects.first {
            XCTAssertEqual(title, L("scan.preview.fit.export.failed.title"))
            XCTAssertEqual(message, String(format: L("scan.preview.fit.export.failed.message"), "disk full"))
            XCTAssertEqual(identifier, "fitExportFailedAlert")
        } else {
            XCTFail("Expected fit export failure alert")
        }
    }

    private func makePreviewInput() -> ScanPreviewInput {
        let pointCloud = class_createInstance(SCPointCloud.self, 0) as! SCPointCloud
        return ScanPreviewInput(
            pointCloud: pointCloud,
            meshTexturing: SCMeshTexturing(),
            earVerificationImage: nil,
            earVerificationSelectionMetadata: nil
        )
    }

    private func makeMeshPlaceholder() -> SCMesh {
        class_createInstance(SCMesh.self, 0) as! SCMesh
    }
}
