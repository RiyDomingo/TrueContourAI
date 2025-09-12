import UIKit

class MeasurementCardView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(icon: UIImage?, title: String, value: String, subtitle: String? = nil) {
        super.init(frame: .zero)
        setupUI()
        iconView.image = icon
        titleLabel.text = title
        valueLabel.text = value
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = (subtitle == nil)
        accessibilityLabel = "\(title): \(value)"
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = UIColor.secondarySystemBackground
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor

        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentHuggingPriority(.required, for: .vertical)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontForContentSizeCategory = true

        valueLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        valueLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.adjustsFontForContentSizeCategory = true

        let labelsStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel, subtitleLabel])
        labelsStack.axis = .vertical
        labelsStack.spacing = 2

        let hStack = UIStackView(arrangedSubviews: [iconView, labelsStack])
        hStack.alignment = .center
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            hStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Public Methods
    
    func updateValue(_ newValue: String, subtitle: String? = nil, animated: Bool = true) {
        let updateBlock = {
            self.valueLabel.text = newValue
            self.subtitleLabel.text = subtitle
            self.subtitleLabel.isHidden = (subtitle == nil)
            self.accessibilityLabel = "\(self.titleLabel.text ?? ""): \(newValue)"
        }
        
        if animated {
            UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve) {
                updateBlock()
            }
        } else {
            updateBlock()
        }
    }
    
    func setError(_ errorMessage: String) {
        valueLabel.text = "--"
        subtitleLabel.text = errorMessage
        subtitleLabel.isHidden = false
        subtitleLabel.textColor = .systemRed
        accessibilityLabel = "\(titleLabel.text ?? ""): Error - \(errorMessage)"
    }
    
    func clearError() {
        subtitleLabel.textColor = .secondaryLabel
    }
}

