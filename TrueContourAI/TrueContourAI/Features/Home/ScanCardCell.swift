import UIKit

final class ScanCardCell: UITableViewCell {

    static let reuseID = "ScanCardCell"

    var onMoreTapped: ((UIView?) -> Void)?
    var onOpenTapped: (() -> Void)?
    private static let thumbnailCache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 40 * 1024 * 1024
        return cache
    }()
    private var currentThumbnailURL: URL?

    private let card: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = DesignSystem.Colors.surface
        v.layer.cornerRadius = DesignSystem.CornerRadius.large
        v.layer.borderWidth = 1
        v.layer.borderColor = DesignSystem.Colors.border.cgColor
        return v
    }()

    private let thumbView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = DesignSystem.Colors.surfaceSecondary
        iv.layer.cornerRadius = DesignSystem.CornerRadius.medium
        iv.layer.masksToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.isAccessibilityElement = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.bodyEmphasis()
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 1
        return l
    }()

    private let qualityBadgeLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = DesignSystem.Colors.textPrimary
        l.font = DesignSystem.Typography.caption()
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 1
        l.textAlignment = .center
        l.layer.cornerRadius = 8
        l.layer.masksToBounds = true
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }()

    private let dateLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = DesignSystem.Colors.textTertiary
        l.font = DesignSystem.Typography.caption()
        l.adjustsFontForContentSizeCategory = true
        l.numberOfLines = 2
        return l
    }()

    private let buttonRow: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .horizontal
        s.spacing = 8
        s.distribution = .fillEqually
        return s
    }()

    private let openButton = ScanActionButton(title: L("scan.card.open"))
    private let moreButton = ScanActionButton(title: L("scan.card.more"))

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureViews()
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(style:reuseIdentifier:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func configureViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(card)
        card.addSubview(thumbView)
        card.addSubview(titleLabel)
        card.addSubview(qualityBadgeLabel)
        card.addSubview(dateLabel)
        card.addSubview(buttonRow)

        buttonRow.addArrangedSubview(openButton)
        buttonRow.addArrangedSubview(moreButton)

        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)

        openButton.accessibilityLabel = L("scan.card.open.label")
        moreButton.accessibilityLabel = L("scan.card.more.label")
        openButton.accessibilityIdentifier = "scanOpenButton"
        moreButton.accessibilityIdentifier = "scanMoreButton"

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            thumbView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            thumbView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            thumbView.widthAnchor.constraint(equalToConstant: 64),
            thumbView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.leadingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: qualityBadgeLabel.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            qualityBadgeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            qualityBadgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            buttonRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            buttonRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            buttonRow.topAnchor.constraint(equalTo: thumbView.bottomAnchor, constant: 12),
            buttonRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            buttonRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentThumbnailURL = nil
        thumbView.image = nil
    }

    func configure(
        title: String,
        date: Date?,
        thumbnailURL: URL?,
        detailText: String?,
        accessibilityDetail: String?,
        qualityBadge: HomeDisplayFormatter.ScanQualityBadgeDisplay?,
        isOpenEnabled: Bool
    ) {
        titleLabel.text = title
        applyQualityBadge(qualityBadge)
        let dateText = date.map { Self.df.string(from: $0) }
        if let dateText, let detailText, !detailText.isEmpty {
            dateLabel.text = "\(dateText)\n\(detailText)"
        } else if let dateText {
            dateLabel.text = dateText
        } else {
            dateLabel.text = detailText
        }
        if let dateText, let accessibilityDetail, !accessibilityDetail.isEmpty {
            accessibilityLabel = "\(title), \(dateText), \(accessibilityDetail)"
        } else if let dateText {
            accessibilityLabel = "\(title), \(dateText)"
        } else if let accessibilityDetail, !accessibilityDetail.isEmpty {
            accessibilityLabel = "\(title), \(accessibilityDetail)"
        } else {
            accessibilityLabel = title
        }
        accessibilityHint = L("scan.card.hint")
        openButton.isEnabled = isOpenEnabled
        DesignSystem.updateButtonEnabled(openButton, style: .secondary)

        currentThumbnailURL = thumbnailURL
        thumbView.image = nil
        guard let url = thumbnailURL else { return }

        if let cached = Self.thumbnailCache.object(forKey: url as NSURL) {
            thumbView.image = cached
            return
        }

        let targetURL = url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let img = UIImage(contentsOfFile: targetURL.path) else { return }
            let cost = Self.cacheCost(for: img)
            Self.thumbnailCache.setObject(img, forKey: targetURL as NSURL, cost: cost)
            DispatchQueue.main.async {
                guard let self, self.currentThumbnailURL == targetURL else { return }
                self.thumbView.image = img
            }
        }
    }

    private static func cacheCost(for image: UIImage) -> Int {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let bytes = pixelWidth * pixelHeight * 4
        return Int(bytes)
    }

    @objc private func openTapped() { onOpenTapped?() }
    @objc private func moreTapped() { onMoreTapped?(moreButton) }

    private func applyQualityBadge(_ badge: HomeDisplayFormatter.ScanQualityBadgeDisplay?) {
        guard let badge else {
            qualityBadgeLabel.isHidden = true
            qualityBadgeLabel.text = nil
            qualityBadgeLabel.accessibilityLabel = nil
            return
        }
        qualityBadgeLabel.isHidden = false
        qualityBadgeLabel.text = " \(badge.text) "
        qualityBadgeLabel.accessibilityLabel = badge.accessibilityText
        switch badge.tier {
        case .high:
            qualityBadgeLabel.backgroundColor = DesignSystem.Colors.qualityGood.withAlphaComponent(0.9)
        case .medium:
            qualityBadgeLabel.backgroundColor = DesignSystem.Colors.qualityOk.withAlphaComponent(0.9)
        case .low:
            qualityBadgeLabel.backgroundColor = DesignSystem.Colors.qualityBad.withAlphaComponent(0.9)
        }
    }
}

private final class ScanActionButton: UIButton {
    init(title: String, destructive: Bool = false) {
        super.init(frame: .zero)
        configure(title: title, destructive: destructive)
    }

    @available(*, unavailable, message: "Programmatic-only. Use init(title:destructive:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func configure(title: String, destructive: Bool) {
        DesignSystem.applyButton(
            self,
            title: title,
            style: destructive ? .destructive : .secondary,
            size: .regular
        )
        heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }
}
