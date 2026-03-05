import Foundation
import StandardCyborgFusion

private enum LocalMeasurementGenerationError: LocalizedError {
    case insufficientPointCloudData

    var errorDescription: String? {
        switch self {
        case .insufficientPointCloudData:
            return "Not enough point cloud data to generate measurements."
        }
    }
}

final class LocalMeasurementGenerationService {
    struct ResultSummary: Codable, Equatable {
        let sliceHeightNormalized: Float
        let circumferenceMm: Float
        let widthMm: Float
        let depthMm: Float
        let confidence: Float
        let status: String
    }

    private let estimator: (SCPointCloud) -> HeadMeasurements?

    init(estimator: @escaping (SCPointCloud) -> HeadMeasurements? = { HeadMeasurementService.estimate(from: $0) }) {
        self.estimator = estimator
    }

    private func dispatchToMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    func generate(
        from pointCloud: SCPointCloud,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<ResultSummary, Error>) -> Void
    ) {
        dispatchToMain {
            progress(0.1)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.dispatchToMain {
                progress(0.5)
            }
            guard let measurement = self.estimator(pointCloud) else {
                self.dispatchToMain {
                    completion(.failure(LocalMeasurementGenerationError.insufficientPointCloudData))
                }
                return
            }

            let confidence = self.estimateConfidence(from: measurement)
            let summary = ResultSummary(
                sliceHeightNormalized: measurement.sliceHeightNormalized,
                circumferenceMm: measurement.circumferenceMm,
                widthMm: measurement.widthMm,
                depthMm: measurement.depthMm,
                confidence: confidence,
                status: confidence >= 0.75 ? "validated" : "estimated"
            )

            self.dispatchToMain {
                progress(1.0)
                completion(.success(summary))
            }
        }
    }

    private func estimateConfidence(from measurement: HeadMeasurements) -> Float {
        let circumferenceScore = clamp((measurement.circumferenceMm - 450) / 220)
        let widthScore = clamp((measurement.widthMm - 120) / 120)
        let depthScore = clamp((measurement.depthMm - 120) / 120)
        return clamp((circumferenceScore * 0.5) + (widthScore * 0.25) + (depthScore * 0.25))
    }

    private func clamp(_ value: Float) -> Float {
        max(0, min(1, value))
    }
}
