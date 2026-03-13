import Foundation

final class ScanTestSeedService {
    private let environment: AppEnvironment
    private let seedRepository: ScanUITestSeedRepository

    init(
        scansRootURL: URL,
        environment: AppEnvironment = .current,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.seedRepository = ScanUITestSeedRepository(
            scansRootURL: scansRootURL,
            fileManager: fileManager
        )
    }

    func seedIfNeeded() {
#if DEBUG
        if environment.seedsScan {
            seedRepository.seedPreviewableScanIfNeeded()
        }
        if environment.seedsMissingSceneScan {
            seedRepository.seedMissingSceneScanIfNeeded()
        }
#endif
    }
}
