import AVFoundation
import Metal
import QuartzCore
import StandardCyborgFusion
import XCTest
@testable import StandardCyborgUI

final class DefaultScanningViewRendererTests: XCTestCase {
    func testDrawCommitsAndPresentsWhenNoFrameIsInflight() {
        let commandQueue = TestCommandQueue()
        let commandBuffer = TestCommandBuffer()
        commandQueue.commandBuffer = commandBuffer
        let renderer = makeRenderer(commandQueue: commandQueue)
        let metalLayer = TestMetalLayer()
        metalLayer.drawable = TestMetalDrawable()

        renderer.draw(colorBuffer: nil,
                      pointCloud: nil,
                      depthCameraCalibrationData: makeCalibrationData(),
                      viewMatrix: matrix_identity_float4x4,
                      into: metalLayer)

        XCTAssertEqual(commandQueue.makeCommandBufferCallCount, 1)
        XCTAssertEqual(commandBuffer.presentCallCount, 1)
        XCTAssertEqual(commandBuffer.commitCallCount, 1)
    }

    func testSecondDrawIsSkippedWhileFrameIsInflight() {
        let commandQueue = TestCommandQueue()
        let firstCommandBuffer = TestCommandBuffer()
        commandQueue.commandBuffer = firstCommandBuffer
        let renderer = makeRenderer(commandQueue: commandQueue)
        let metalLayer = TestMetalLayer()
        metalLayer.drawable = TestMetalDrawable()

        renderer.draw(colorBuffer: nil,
                      pointCloud: nil,
                      depthCameraCalibrationData: makeCalibrationData(),
                      viewMatrix: matrix_identity_float4x4,
                      into: metalLayer)
        renderer.draw(colorBuffer: nil,
                      pointCloud: nil,
                      depthCameraCalibrationData: makeCalibrationData(),
                      viewMatrix: matrix_identity_float4x4,
                      into: metalLayer)

        XCTAssertEqual(commandQueue.makeCommandBufferCallCount, 1)
        XCTAssertEqual(firstCommandBuffer.commitCallCount, 1)
    }

    func testScheduledFrameAllowsNextDraw() {
        let commandQueue = TestCommandQueue()
        let firstCommandBuffer = TestCommandBuffer()
        commandQueue.commandBuffer = firstCommandBuffer
        let renderer = makeRenderer(commandQueue: commandQueue)
        let metalLayer = TestMetalLayer()
        metalLayer.drawable = TestMetalDrawable()

        renderer.draw(colorBuffer: nil,
                      pointCloud: nil,
                      depthCameraCalibrationData: makeCalibrationData(),
                      viewMatrix: matrix_identity_float4x4,
                      into: metalLayer)

        firstCommandBuffer.runScheduledHandlers()

        let secondCommandBuffer = TestCommandBuffer()
        commandQueue.commandBuffer = secondCommandBuffer
        renderer.draw(colorBuffer: nil,
                      pointCloud: nil,
                      depthCameraCalibrationData: makeCalibrationData(),
                      viewMatrix: matrix_identity_float4x4,
                      into: metalLayer)

        XCTAssertEqual(commandQueue.makeCommandBufferCallCount, 2)
        XCTAssertEqual(secondCommandBuffer.commitCallCount, 1)
    }

    private func makeRenderer(commandQueue: TestCommandQueue) -> DefaultScanningViewRenderer {
        let device = MTLCreateSystemDefaultDevice()!
        return DefaultScanningViewRenderer(
            device: device,
            commandQueue: commandQueue,
            makeLibrary: {
                throw NSError(domain: "DefaultScanningViewRendererTests", code: 1)
            }
        )
    }

    private func makeCalibrationData() -> AVCameraCalibrationData {
        unsafeBitCast(NSObject(), to: AVCameraCalibrationData.self)
    }
}

private final class TestCommandQueue: ScanningCommandQueueing {
    var commandBuffer: TestCommandBuffer?
    var makeCommandBufferCallCount = 0

    func makeCommandBuffer() -> ScanningCommandBuffering? {
        makeCommandBufferCallCount += 1
        return commandBuffer
    }
}

private final class TestCommandBuffer: ScanningCommandBuffering {
    var label: String?
    var presentCallCount = 0
    var commitCallCount = 0
    private var scheduledHandlers: [(MTLCommandBuffer) -> Void] = []
    private var completionHandlers: [(MTLCommandBuffer) -> Void] = []

    func present(_ drawable: CAMetalDrawable) {
        presentCallCount += 1
    }

    func commit() {
        commitCallCount += 1
    }

    func addScheduledHandler(_ handler: @escaping (MTLCommandBuffer) -> Void) {
        scheduledHandlers.append(handler)
    }

    func addCompletedHandler(_ handler: @escaping (MTLCommandBuffer) -> Void) {
        completionHandlers.append(handler)
    }

    func runScheduledHandlers() {
        let fakeCommandBuffer = unsafeBitCast(NSObject(), to: MTLCommandBuffer.self)
        scheduledHandlers.forEach { $0(fakeCommandBuffer) }
    }

    func runCompletionHandlers() {
        let fakeCommandBuffer = unsafeBitCast(NSObject(), to: MTLCommandBuffer.self)
        completionHandlers.forEach { $0(fakeCommandBuffer) }
    }
}

private final class TestMetalLayer: CAMetalLayer {
    var drawable: CAMetalDrawable?

    override func nextDrawable() -> CAMetalDrawable? {
        drawable
    }
}

private final class TestMetalDrawable: NSObject, CAMetalDrawable {
    let texture: MTLTexture = unsafeBitCast(NSObject(), to: MTLTexture.self)
    let layer: CAMetalLayer = CAMetalLayer()
    var presentedTime: CFTimeInterval = 0

    func present() {}
    func present(at presentationTime: CFTimeInterval) {}
    func present(afterMinimumDuration duration: CFTimeInterval) {}
}
