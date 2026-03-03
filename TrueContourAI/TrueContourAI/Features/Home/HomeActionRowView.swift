import UIKit

final class HomeActionRowView: UIStackView {
    let viewLastScanButton: UIButton = {
        let b = UIButton(type: .system)
        DesignSystem.applyButton(b, title: L("home.viewlast"), style: .secondary, size: .regular)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        b.accessibilityLabel = L("home.accessibility.viewlast")
        b.accessibilityHint = L("home.accessibility.viewlast.hint")
        b.accessibilityIdentifier = "viewLastScanButton"
        return b
    }()

    let openScansFolderButton: UIButton = {
        let b = UIButton(type: .system)
        DesignSystem.applyButton(b, title: L("home.scansfolder"), style: .secondary, size: .regular)
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        b.accessibilityLabel = L("home.accessibility.scansfolder")
        b.accessibilityHint = L("home.accessibility.scansfolder.hint")
        b.accessibilityIdentifier = "openScansFolderButton"
        return b
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        axis = .horizontal
        spacing = 10
        distribution = .fillEqually
        addArrangedSubview(viewLastScanButton)
        addArrangedSubview(openScansFolderButton)
    }

    @available(*, unavailable, message: "Programmatic-only. Use init().")
    required init(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}
