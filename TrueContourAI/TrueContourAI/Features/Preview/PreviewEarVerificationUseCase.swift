import UIKit

final class PreviewEarVerificationUseCase {
    func makeRequest(
        preservedImage: UIImage?,
        preservedSelectionMetadata: EarVerificationSelectionMetadata?,
        previewSnapshot: UIImage
    ) -> PreviewEarVerificationRequest {
        let source: PreviewStore.EarVerificationImageSource =
            preservedSelectionMetadata.map {
                switch $0.source {
                case .bestCaptureFrame:
                    return .bestCaptureFrame
                case .latestCaptureFallback:
                    return .latestCaptureFallback
                }
            } ?? (preservedImage != nil ? .latestCaptureFallback : .previewSnapshotFallback)

        return PreviewEarVerificationRequest(
            verificationImage: preservedImage ?? previewSnapshot,
            source: source,
            selectionMetadata: preservedSelectionMetadata
        )
    }

    func verify(
        service: EarLandmarksService,
        request: PreviewEarVerificationRequest,
        completion: @escaping (Result<PreviewEarVerificationResult, PreviewFailure>) -> Void
    ) {
        PreviewQoSQueues.earVerification.async {
            do {
                guard let verification = try service.verify(
                    in: request.verificationImage,
                    verificationSource: request.source.rawValue,
                    usedPreviewSnapshotFallback: request.source == .previewSnapshotFallback,
                    selectionMetadata: request.selectionMetadata
                ) else {
                    DispatchQueue.main.async {
                        completion(.failure(.verificationFailed(L("scan.preview.noEar.message"))))
                    }
                    return
                }

                DispatchQueue.main.async {
                    completion(.success(
                        PreviewEarVerificationResult(
                            earImage: verification.verificationImage,
                            earResult: verification.result,
                            earOverlay: verification.fullSceneOverlay,
                            earCropOverlay: verification.cropOverlay
                        )
                    ))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.verificationFailed(error.localizedDescription)))
                }
            }
        }
    }
}
