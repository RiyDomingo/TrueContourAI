import AVFoundation
import CoreMotion
import Foundation
import QuartzCore
import StandardCyborgFusion
import simd
import UIKit

protocol ScanRuntimeEngining: AnyObject {
    var onEvent: ((ScanRuntimeEvent) -> Void)? { get set }
    var onRenderFrame: ((ScanRenderFrame) -> Void)? { get set }
    var diagnosticsSnapshot: ScanRuntimeDiagnosticsSnapshot { get }

    func activate()
    func deactivate()
    func beginCapture(autoFinishSeconds: Int)
    func processFrame(_ frame: ScanFramePayload, isScanning: Bool)
    func finishCapture()
    func cancelCapture()
}

final class ScanRuntimeEngine: NSObject, ScanRuntimeEngining, SCReconstructionManagerDelegate {
    private struct DistanceStabilityTracker {
        private let maxSamples: Int
        private var samples: [Float] = []
        private var nextIndex = 0

        init(maxSamples: Int = 8) {
            self.maxSamples = maxSamples
            self.samples.reserveCapacity(maxSamples)
        }

        mutating func reset() {
            samples.removeAll(keepingCapacity: true)
            nextIndex = 0
        }

        mutating func add(_ value: Float) {
            if samples.count < maxSamples {
                samples.append(value)
                return
            }
            samples[nextIndex] = value
            nextIndex = (nextIndex + 1) % maxSamples
        }

        func shouldWarn(threshold: Float) -> Bool {
            guard samples.count >= maxSamples else { return false }
            guard let minValue = samples.min(), let maxValue = samples.max() else { return false }
            return (maxValue - minValue) > threshold
        }
    }

    var onEvent: ((ScanRuntimeEvent) -> Void)?
    var onRenderFrame: ((ScanRenderFrame) -> Void)?

    var diagnosticsSnapshot: ScanRuntimeDiagnosticsSnapshot {
        ScanRuntimeDiagnosticsSnapshot(
            succeededCount: latestReconstructionStatistics.succeededCount,
            lostTrackingCount: latestReconstructionStatistics.lostTrackingCount,
            droppedFrameCount: latestReconstructionStatistics.droppedFrameCount
        )
    }

    private let reconstructionManager: ReconstructionManaging
    private let runtimeController: ScanRuntimeController
    private let motionManager: CMMotionManager
    private let backgroundWorkRunner: (@escaping () -> Void) -> Void

    private let configuration: ScanRuntimeConfiguration
    private let developerModeEnabled: Bool
    private let requiresManualFinish: Bool
    private var autoFinishSeconds = 0
    private var isScanning = false
    private var meshTexturing = SCMeshTexturing()
    private var latestViewMatrix = matrix_identity_float4x4
    private var assimilatedFrameIndex = 0
    private var consecutiveFailedCount = 0
    private var smoothedMotionSamples: [Double] = []
    private var previewSnapshotCache: SCPointCloud?
    private var lastPreviewSnapshotBuiltAt: CFTimeInterval = -.greatestFiniteMagnitude
    private var lastPreviewSnapshotRequestedAt: CFTimeInterval = -.greatestFiniteMagnitude
    private var latestReconstructionStatistics = SCReconstructionManagerStatistics()
    private var distanceTracker = DistanceStabilityTracker()

    private let minSucceededFramesForCompletion = 50
    private let unstableMotionThreshold: Double = 0.16
    private let goodTrackingFrameInterval = 40
    private let motionSampleWindowSize = 6
    private let distanceInstabilityThreshold: Float = 0.08
    private let textureSaveSuppressionAssimilationWindow = 8
    private let previewSnapshotMinimumInterval: CFTimeInterval = 0.15
    private var suppressTextureSavingUntilAssimilationIndex = 0

    init(
        reconstructionManager: ReconstructionManaging,
        runtimeController: ScanRuntimeController = ScanRuntimeController(),
        motionManager: CMMotionManager = CMMotionManager(),
        configuration: ScanRuntimeConfiguration,
        developerModeEnabled: Bool,
        requiresManualFinish: Bool,
        backgroundWorkRunner: @escaping (@escaping () -> Void) -> Void
    ) {
        self.reconstructionManager = reconstructionManager
        self.runtimeController = runtimeController
        self.motionManager = motionManager
        self.configuration = configuration
        self.developerModeEnabled = developerModeEnabled
        self.requiresManualFinish = requiresManualFinish
        self.backgroundWorkRunner = backgroundWorkRunner
        super.init()
        reconstructionManager.delegate = self
        reconstructionManager.includesColorBuffersInMetadata = configuration.texturedMeshEnabled
        runtimeController.onCriticalThermalState = { [weak self] in
            self?.onEvent?(.thermalShutdown)
        }
    }

    func activate() {
        runtimeController.activate()
        startMotionUpdates()
        onEvent?(.sessionReady)
    }

    func deactivate() {
        runtimeController.deactivate()
        motionManager.stopDeviceMotionUpdates()
        isScanning = false
    }

    func beginCapture(autoFinishSeconds: Int) {
        self.autoFinishSeconds = autoFinishSeconds
        isScanning = true
        assimilatedFrameIndex = 0
        consecutiveFailedCount = 0
        smoothedMotionSamples.removeAll(keepingCapacity: true)
        distanceTracker.reset()
        invalidatePreviewSnapshotCache()
        suppressTextureSavingUntilAssimilationIndex = 0
        latestViewMatrix = matrix_identity_float4x4
        runtimeController.updateScanningState(isScanning: true)
        onEvent?(
            .guidance(
                ScanGuidanceSignal(
                    promptText: L("scanning.guidance.short.start"),
                    chipText: L("scanning.guidance.status.caution"),
                    chipStyle: .caution,
                    focusHintText: nil
                )
            )
        )
        onEvent?(.progress(makeProgressSnapshot()))
    }

    func processFrame(_ frame: ScanFramePayload, isScanning: Bool) {
        self.isScanning = isScanning
        let pointCloud: SCPointCloud?
        if isScanning {
            pointCloud = activeScanPreviewPointCloud(now: frame.timestamp)
        } else {
            invalidatePreviewSnapshotCache()
            pointCloud = reconstructionManager.reconstructSingleDepthBuffer(
                frame.depthBuffer,
                colorBuffer: nil,
                with: frame.calibrationData,
                smoothingPoints: true
            )
        }

        onRenderFrame?(
            ScanRenderFrame(
                colorBuffer: frame.colorBuffer,
                pointCloud: pointCloud,
                calibrationData: frame.calibrationData,
                viewMatrix: latestViewMatrix
            )
        )

        if isScanning {
            reconstructionManager.accumulate(
                depthBuffer: frame.depthBuffer,
                colorBuffer: frame.colorBuffer,
                calibrationData: frame.calibrationData
            )
        }
    }

    func finishCapture() {
        guard isScanning else { return }
        isScanning = false
        runtimeController.updateScanningState(isScanning: false)
        if let calibrationData = reconstructionManager.latestCameraCalibrationData {
            meshTexturing.cameraCalibrationData = calibrationData
            meshTexturing.cameraCalibrationFrameWidth = reconstructionManager.latestCameraCalibrationFrameWidth
            meshTexturing.cameraCalibrationFrameHeight = reconstructionManager.latestCameraCalibrationFrameHeight
        }
        reconstructionManager.finalize { [weak self] in
            guard let self else { return }
            let completedMeshTexturing = self.meshTexturing
            self.backgroundWorkRunner { [weak self] in
                guard let self else { return }
                let pointCloud = self.reconstructionManager.buildPointCloud()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.reconstructionManager.reset()
                    self.meshTexturing = SCMeshTexturing()
                    self.onEvent?(
                        .completed(
                            ScanPreviewInput(
                                pointCloud: pointCloud,
                                meshTexturing: completedMeshTexturing,
                                earVerificationImage: nil,
                                earVerificationSelectionMetadata: nil
                            )
                        )
                    )
                }
            }
        }
    }

    func cancelCapture() {
        isScanning = false
        runtimeController.updateScanningState(isScanning: false)
        reconstructionManager.reset()
        meshTexturing = SCMeshTexturing()
        invalidatePreviewSnapshotCache()
    }

    func reconstructionManager(
        _ manager: SCReconstructionManager,
        didProcessWith metadata: SCAssimilatedFrameMetadata,
        statistics: SCReconstructionManagerStatistics
    ) {
        guard isScanning else { return }
        latestViewMatrix = metadata.viewMatrix
        latestReconstructionStatistics = statistics
        updateDistanceGuidanceIfNeeded(with: metadata.viewMatrix)

        switch metadata.result {
        case .succeeded, .poorTracking:
            refreshActivePreviewSnapshotIfNeeded(now: CACurrentMediaTime())
            let shouldSaveTextureBuffer = configuration.texturedMeshEnabled &&
                assimilatedFrameIndex >= suppressTextureSavingUntilAssimilationIndex
            if shouldSaveTextureBuffer,
               assimilatedFrameIndex % max(1, configuration.textureSaveInterval) == 0,
               let colorBuffer = metadata.colorBuffer?.takeUnretainedValue() {
                meshTexturing.saveColorBufferForReconstruction(
                    colorBuffer,
                    withViewMatrix: metadata.viewMatrix,
                    projectionMatrix: metadata.projectionMatrix
                )
            }
            assimilatedFrameIndex += 1
            consecutiveFailedCount = 0
            onEvent?(.progress(makeProgressSnapshot()))
            if metadata.result == .poorTracking {
                emitGuidance(message: L("scanning.guidance.short.poorTracking"), style: .caution)
                suppressTextureSavingUntilAssimilationIndex = max(
                    suppressTextureSavingUntilAssimilationIndex,
                    assimilatedFrameIndex + textureSaveSuppressionAssimilationWindow
                )
            } else if assimilatedFrameIndex % goodTrackingFrameInterval == 0 {
                emitGuidance(message: L("scanning.guidance.short.goodTracking"), style: .good)
            }
        case .failed:
            consecutiveFailedCount += 1
            emitGuidance(message: L("scanning.guidance.short.trackingLost"), style: .warning)
            if !requiresManualFinish {
                let belowMinFrames = statistics.succeededCount < minSucceededFramesForCompletion
                let exceededFailureTolerance = consecutiveFailedCount >= 5
                if belowMinFrames && exceededFailureTolerance {
                    onEvent?(.failed(.canceled))
                }
            }
        case .lostTracking:
            emitGuidance(message: L("scanning.guidance.short.trackingLost"), style: .warning)
        @unknown default:
            break
        }
    }

    func reconstructionManager(_ manager: SCReconstructionManager, didEncounterAPIError error: Error) {
        onEvent?(.failed(.reconstructionFailed(error.localizedDescription)))
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion, self.isScanning else { return }
            self.reconstructionManager.accumulateDeviceMotion(motion)
            _ = self.handleMotionGuidance(forMagnitude: self.smoothedMotionMagnitude(with: motion))
        }
    }

    private func smoothedMotionMagnitude(with motion: CMDeviceMotion) -> Double {
        let acceleration = motion.userAcceleration
        let magnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )
        smoothedMotionSamples.append(magnitude)
        if smoothedMotionSamples.count > motionSampleWindowSize {
            smoothedMotionSamples.removeFirst()
        }
        let sum = smoothedMotionSamples.reduce(0, +)
        return sum / Double(smoothedMotionSamples.count)
    }

    @discardableResult
    private func handleMotionGuidance(forMagnitude magnitude: Double) -> Bool {
        guard magnitude > unstableMotionThreshold else { return false }
        emitGuidance(message: L("scanning.guidance.short.motion"), style: .caution)
        return true
    }

    private func updateDistanceGuidanceIfNeeded(with viewMatrix: simd_float4x4) {
        let translation = SIMD3<Float>(viewMatrix.columns.3.x, viewMatrix.columns.3.y, viewMatrix.columns.3.z)
        distanceTracker.add(simd_length(translation))
        if distanceTracker.shouldWarn(threshold: distanceInstabilityThreshold) {
            emitGuidance(message: L("scanning.guidance.short.distance"), style: .caution)
        }
    }

    private func emitGuidance(message: String, style: GuidanceChipStyle) {
        let chipText: String?
        switch style {
        case .good:
            chipText = L("scanning.guidance.status.good")
        case .neutral, .caution:
            chipText = L("scanning.guidance.status.caution")
        case .warning:
            chipText = L("scanning.guidance.status.lost")
        }
        onEvent?(
            .guidance(
                ScanGuidanceSignal(
                    promptText: message,
                    chipText: chipText,
                    chipStyle: style,
                    focusHintText: nil
                )
            )
        )
    }

    private func makeProgressSnapshot() -> ScanProgressSnapshot {
        if autoFinishSeconds > 0 {
            let capturedSeconds = min(autoFinishSeconds, Int(round(Float(assimilatedFrameIndex) / 30.0)))
            let progressFraction = min(max(Float(capturedSeconds) / Float(autoFinishSeconds), 0), 1)
            return ScanProgressSnapshot(
                capturedSeconds: capturedSeconds,
                targetSeconds: autoFinishSeconds,
                progressFraction: progressFraction,
                manualFinishAllowed: requiresManualFinish,
                developerDiagnosticsText: developerModeEnabled ? developerDiagnosticsText() : nil
            )
        }
        let progressFraction = min(max(Float(assimilatedFrameIndex) / Float(minSucceededFramesForCompletion), 0), 1)
        return ScanProgressSnapshot(
            capturedSeconds: assimilatedFrameIndex,
            targetSeconds: minSucceededFramesForCompletion,
            progressFraction: progressFraction,
            manualFinishAllowed: requiresManualFinish,
            developerDiagnosticsText: developerModeEnabled ? developerDiagnosticsText() : nil
        )
    }

    private func developerDiagnosticsText() -> String {
        let stats = latestReconstructionStatistics
        return "recon ok=\(stats.succeededCount) lost=\(stats.lostTrackingCount) drop=\(stats.droppedFrameCount)"
    }

    private func activeScanPreviewPointCloud(now: CFTimeInterval) -> SCPointCloud? {
        if let cachedSnapshot = previewSnapshotCache,
           (now - lastPreviewSnapshotBuiltAt) < previewSnapshotMinimumInterval {
            return cachedSnapshot
        }

        if let cachedSnapshot = previewSnapshotCache {
            return cachedSnapshot
        }

        return nil
    }

    private func refreshActivePreviewSnapshotIfNeeded(now: CFTimeInterval) {
        guard isScanning else { return }
        if (now - lastPreviewSnapshotRequestedAt) < previewSnapshotMinimumInterval {
            return
        }
        lastPreviewSnapshotRequestedAt = now
        guard let snapshot = reconstructionManager.buildPointCloudSnapshot() else {
            return
        }
        previewSnapshotCache = snapshot
        lastPreviewSnapshotBuiltAt = now
    }

    private func invalidatePreviewSnapshotCache() {
        previewSnapshotCache = nil
        lastPreviewSnapshotBuiltAt = -.greatestFiniteMagnitude
        lastPreviewSnapshotRequestedAt = -.greatestFiniteMagnitude
    }
}
