import UIKit

final class PreviewAlertPresenter {
    func makeAlert(title: String, message: String, identifier: String? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("common.ok"), style: .default))
        if let identifier {
            alert.view.accessibilityIdentifier = identifier
        }
        return alert
    }

    func presentAlert(
        on presenter: UIViewController,
        title: String,
        message: String,
        identifier: String? = nil,
        animated: Bool = true
    ) {
        presenter.present(makeAlert(title: title, message: message, identifier: identifier), animated: animated)
    }
}
