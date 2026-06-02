import UIKit
import ImageIO

enum AdsDebugTheme {
    static let background = UIColor(red: 17 / 255, green: 24 / 255, blue: 39 / 255, alpha: 1)
    static let card = UIColor(red: 31 / 255, green: 41 / 255, blue: 55 / 255, alpha: 0.75)
    static let cardSolid = UIColor(red: 31 / 255, green: 41 / 255, blue: 55 / 255, alpha: 1)
    static let textPrimary = UIColor(red: 249 / 255, green: 250 / 255, blue: 251 / 255, alpha: 1)
    static let textSecondary = UIColor(red: 209 / 255, green: 213 / 255, blue: 219 / 255, alpha: 1)
    static let textMuted = UIColor(red: 156 / 255, green: 163 / 255, blue: 175 / 255, alpha: 1)
    static let success = UIColor(red: 22 / 255, green: 163 / 255, blue: 74 / 255, alpha: 1)
    static let failed = UIColor(red: 225 / 255, green: 29 / 255, blue: 72 / 255, alpha: 1)
    static let loading = UIColor(red: 245 / 255, green: 158 / 255, blue: 11 / 255, alpha: 1)
    static let accent = UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1)
    static let tabSelected = UIColor(red: 55 / 255, green: 69 / 255, blue: 90 / 255, alpha: 0.9)
    static let switchOn = UIColor(red: 20 / 255, green: 83 / 255, blue: 45 / 255, alpha: 0.8)
    static let border = UIColor.white.withAlphaComponent(0.09)
    static let buttonBorder = UIColor(red: 124 / 255, green: 133 / 255, blue: 148 / 255, alpha: 0.5)
    static let cardCornerRadius: CGFloat = 12
    static let cardHorizontalInset: CGFloat = 16
    static let cardVerticalGap: CGFloat = 8
    static let cardContentHorizontalPadding: CGFloat = 12
    static let cardContentVerticalPadding: CGFloat = 12

    static func cardCell(_ cell: UITableViewCell) {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = card
        cell.contentView.layer.cornerRadius = cardCornerRadius
        cell.contentView.layer.borderWidth = 0
        cell.contentView.layer.masksToBounds = true
        cell.contentView.layoutMargins = UIEdgeInsets(
            top: cardContentVerticalPadding,
            left: cardContentHorizontalPadding,
            bottom: cardContentVerticalPadding,
            right: cardContentHorizontalPadding
        )
        cell.preservesSuperviewLayoutMargins = false
        cell.textLabel?.textColor = textPrimary
        cell.detailTextLabel?.textColor = textSecondary
        cell.tintColor = accent
    }

    static func sectionHeader(title: String) -> UIView {
        let view = AdsDebugSectionHeaderView()
        view.backgroundColor = .clear

        let label = UILabel()
        label.text = title
        label.textColor = textPrimary
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 1
        label.layer.shadowRadius = 8
        label.layer.shadowOffset = CGSize(width: 0, height: 3)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        return view
    }

    static func statusColor(_ status: AdDebugExternalStatus) -> UIColor {
        switch status {
        case .success: return success
        case .failed: return failed
        case .submitted: return loading
        case .raw, .debug: return textSecondary
        }
    }
}

final class AdsDebugTableView: UITableView {
    init() {
        super.init(frame: .zero, style: .plain)
        backgroundColor = .clear
        separatorStyle = .none
        contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 24, right: 0)
        estimatedRowHeight = 76
        rowHeight = UITableView.automaticDimension
        sectionFooterHeight = 0
        tableFooterView = UIView(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class AdsDebugCardTableViewCell: UITableViewCell {
    let titleLabel = UILabel()
    let detailLabel = UILabel()

    private let cardView = UIView()
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.backgroundColor = AdsDebugTheme.card
        cardView.layer.cornerRadius = AdsDebugTheme.cardCornerRadius
        cardView.layer.masksToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        titleLabel.textColor = AdsDebugTheme.textPrimary
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.numberOfLines = 0

        detailLabel.textColor = AdsDebugTheme.textSecondary
        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.numberOfLines = 0

        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(detailLabel)

        let verticalGap = AdsDebugTheme.cardVerticalGap / 2
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalGap),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalGap),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AdsDebugTheme.cardHorizontalInset),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AdsDebugTheme.cardHorizontalInset),

            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AdsDebugTheme.cardContentVerticalPadding),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AdsDebugTheme.cardContentVerticalPadding),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AdsDebugTheme.cardContentHorizontalPadding),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AdsDebugTheme.cardContentHorizontalPadding)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.attributedText = nil
        titleLabel.text = nil
        titleLabel.textColor = AdsDebugTheme.textPrimary
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        detailLabel.attributedText = nil
        detailLabel.text = nil
        detailLabel.textColor = AdsDebugTheme.textSecondary
        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.isHidden = false
        selectionStyle = .none
    }

    func configure(
        title: NSAttributedString,
        detail: NSAttributedString? = nil,
        titleColor: UIColor? = nil,
        titleFont: UIFont = .systemFont(ofSize: 15, weight: .semibold),
        detailFont: UIFont = .systemFont(ofSize: 12, weight: .regular)
    ) {
        titleLabel.attributedText = title
        titleLabel.font = titleFont
        if let titleColor {
            titleLabel.textColor = titleColor
        }
        detailLabel.attributedText = detail
        detailLabel.font = detailFont
        detailLabel.isHidden = detail == nil || detail?.string.isEmpty == true
    }

    func configure(
        title: String,
        detail: String? = nil,
        titleColor: UIColor? = nil,
        titleFont: UIFont = .systemFont(ofSize: 15, weight: .semibold),
        detailFont: UIFont = .systemFont(ofSize: 12, weight: .regular)
    ) {
        configure(
            title: NSAttributedString(string: title),
            detail: detail.map(NSAttributedString.init(string:)),
            titleColor: titleColor,
            titleFont: titleFont,
            detailFont: detailFont
        )
    }
}

final class AdsDebugMonoTableViewCell: UITableViewCell {
    private let monoLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        monoLabel.numberOfLines = 0
        monoLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        monoLabel.textColor = AdsDebugTheme.textSecondary
        monoLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(monoLabel)

        NSLayoutConstraint.activate([
            monoLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            monoLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            monoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AdsDebugTheme.cardHorizontalInset),
            monoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AdsDebugTheme.cardHorizontalInset)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        monoLabel.text = nil
        monoLabel.textColor = AdsDebugTheme.textSecondary
    }

    func configure(text: String, color: UIColor = AdsDebugTheme.textSecondary) {
        monoLabel.text = text
        monoLabel.textColor = color
    }
}

private final class AdsDebugSectionHeaderView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class AdsDebugBackgroundView: UIView {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AdsDebugTheme.background
        isUserInteractionEnabled = false

        imageView.contentMode = .scaleAspectFill
        imageView.alpha = 0.15
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        if let url = Bundle.module.url(forResource: "ads_debug_background", withExtension: "gif") {
            imageView.image = UIImage.adsDebugAnimatedGIF(url: url)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension UIImage {
    static func adsDebugAnimatedGIF(url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return UIImage(contentsOfFile: url.path)
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else {
            return UIImage(contentsOfFile: url.path)
        }

        var frames: [UIImage] = []
        var duration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            duration += adsDebugGIFDelay(source: source, index: index)
            frames.append(UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up))
        }

        guard !frames.isEmpty else { return UIImage(contentsOfFile: url.path) }
        return UIImage.animatedImage(with: frames, duration: max(duration, Double(frames.count) * 0.08))
    }

    static func adsDebugGIFDelay(source: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.08
        }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? NSNumber
        let delay = unclamped?.doubleValue ?? clamped?.doubleValue ?? 0.08
        return delay < 0.02 ? 0.08 : delay
    }
}
