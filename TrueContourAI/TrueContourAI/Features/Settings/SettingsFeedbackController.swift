import UIKit

final class SettingsFeedbackController {
    private weak var presenter: UIViewController?

    init(presenter: UIViewController) {
        self.presenter = presenter
    }

    func presentOptionSheet(
        title: String,
        options: [SettingsOption],
        selected: Int,
        onSelect: @escaping (Int) -> Void
    ) {
        guard let presenter else { return }

        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            let optionTitle = option.value == selected
                ? option.title + L("settings.option.currentSuffix")
                : option.title
            alert.addAction(UIAlertAction(title: optionTitle, style: .default, handler: { _ in
                onSelect(option.value)
            }))
        }
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        }
        presenter.present(alert, animated: true)
    }

    func confirmReset(onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(
            title: L("settings.reset.confirm.title"),
            message: L("settings.reset.confirm.message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("settings.reset.action"), style: .destructive, handler: { _ in
            onConfirm()
        }))
        presenter?.present(alert, animated: true)
    }

    func confirmDeleteAllScans(onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(
            title: L("settings.deleteAll.confirm.title"),
            message: L("settings.deleteAll.confirm.message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("common.delete"), style: .destructive, handler: { _ in
            onConfirm()
        }))
        presenter?.present(alert, animated: true)
    }

    func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        presenter?.present(alert, animated: true)
    }
}
