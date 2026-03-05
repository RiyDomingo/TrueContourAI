import UIKit

final class HomeToastPresenter {
    private weak var hostView: UIView?

    init(hostView: UIView) {
        self.hostView = hostView
    }

    func show(message: String) {
        guard let hostView else { return }

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textColor = DesignSystem.Colors.textPrimary
        label.font = DesignSystem.Typography.caption()
        label.backgroundColor = DesignSystem.Colors.overlay
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityIdentifier = "toastLabel"
        label.layer.cornerRadius = DesignSystem.CornerRadius.medium
        label.layer.masksToBounds = true
        label.alpha = 0

        hostView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            label.bottomAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.bottomAnchor, constant: -18)
        ])

        UIView.animate(withDuration: 0.22) { label.alpha = 1 }
        let args = ProcessInfo.processInfo.arguments
        let dwellSeconds: TimeInterval = args.contains("ui-test-device-smoke") ? 8.0 : 1.8
        DispatchQueue.main.asyncAfter(deadline: .now() + dwellSeconds) {
            UIView.animate(withDuration: 0.22, animations: { label.alpha = 0 }) { _ in
                label.removeFromSuperview()
            }
        }
    }
}
