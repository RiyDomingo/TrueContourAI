import UIKit

final class PreviewEarVerificationUseCase {
    func verify(
        service: EarLandmarksService,
        verificationImage: UIImage,
        source: PreviewStore.EarVerificationImageSource,
        selectionMetadata: EarVerificationSelectionMetadata?,
        completion: @escaping (Result<PreviewEarVerificationResult, PreviewFailure>) -> Void
    ) {
        PreviewQoSQueues.earVerification.async {
            do {
                guard let verification = try service.verify(
                    in: verificationImage,
                    verificationSource: source.rawValue,
                    usedPreviewSnapshotFallback: source == .previewSnapshotFallback,
                    selectionMetadata: selectionMetadata
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
