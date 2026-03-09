import UIKit

final class HomeFeedbackController {
    private weak var hostViewController: UIViewController?
    private let environment: AppEnvironment
    private let diagnosticsTextProvider: () -> String?
    private lazy var toastPresenter = HomeToastPresenter(hostView: diagnosticsLabel.superview ?? hostViewController?.view ?? UIView(), environment: environment)

    let diagnosticsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = DesignSystem.Colors.textSecondary
        label.font = DesignSystem.Typography.caption()
        label.numberOfLines = 0
        label.accessibilityIdentifier = "deviceSmokeDiagnosticsLabel"
        label.isHidden = true
        return label
    }()

    init(
        hostViewController: UIViewController,
        environment: AppEnvironment,
        diagnosticsTextProvider: @escaping () -> String?
    ) {
        self.hostViewController = hostViewController
        self.environment = environment
        self.diagnosticsTextProvider = diagnosticsTextProvider
    }

    func handleToast(_ message: String) {
#if DEBUG
        if message.hasPrefix("diag:") {
            updateDiagnostics(message.replacingOccurrences(of: "diag:", with: ""))
            return
        }
#endif
        toastPresenter.show(message: message)
    }

    func presentStorageUnavailableAlert() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let hostViewController, hostViewController.presentedViewController == nil else { return }
            let alert = UIAlertController(
                title: L("scan.storage.unavailable.title"),
                message: L("scan.storage.unavailable.message"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
            hostViewController.present(alert, animated: true)
        }
    }

    func refreshDiagnosticsIfNeeded() {
#if DEBUG
        guard environment.isDeviceSmokeMode else {
            diagnosticsLabel.isHidden = true
            diagnosticsLabel.text = nil
            return
        }

        guard let diagnosticsText = diagnosticsTextProvider() else {
            diagnosticsLabel.isHidden = true
            diagnosticsLabel.text = nil
            return
        }

        updateDiagnostics(diagnosticsText)
#else
        diagnosticsLabel.isHidden = true
        diagnosticsLabel.text = nil
#endif
    }

#if DEBUG
    private func updateDiagnostics(_ text: String) {
        guard environment.isDeviceSmokeMode else { return }
        diagnosticsLabel.text = text
        diagnosticsLabel.accessibilityLabel = text
        diagnosticsLabel.isHidden = false
    }
#endif
}
