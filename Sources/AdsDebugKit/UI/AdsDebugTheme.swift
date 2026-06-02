import UIKit
import ImageIO

enum AdsDebugTheme {
    enum Style {
        case dark
        case light
    }

    static var style: Style = .dark

    static var background: UIColor {
        switch style {
        case .dark: return UIColor(red: 17 / 255, green: 24 / 255, blue: 39 / 255, alpha: 1)
        case .light: return UIColor(red: 248 / 255, green: 250 / 255, blue: 252 / 255, alpha: 1)
        }
    }

    static var card: UIColor {
        switch style {
        case .dark: return UIColor(red: 31 / 255, green: 41 / 255, blue: 55 / 255, alpha: 0.78)
        case .light: return UIColor.white.withAlphaComponent(0.80)
        }
    }

    static var cardSolid: UIColor {
        switch style {
        case .dark: return UIColor(red: 31 / 255, green: 41 / 255, blue: 55 / 255, alpha: 1)
        case .light: return UIColor.white
        }
    }

    static var textPrimary: UIColor {
        switch style {
        case .dark: return UIColor(red: 249 / 255, green: 250 / 255, blue: 251 / 255, alpha: 1)
        case .light: return UIColor(red: 15 / 255, green: 23 / 255, blue: 42 / 255, alpha: 1)
        }
    }

    static var textSecondary: UIColor {
        switch style {
        case .dark: return UIColor(red: 209 / 255, green: 213 / 255, blue: 219 / 255, alpha: 1)
        case .light: return UIColor(red: 51 / 255, green: 65 / 255, blue: 85 / 255, alpha: 1)
        }
    }

    static var textMuted: UIColor {
        switch style {
        case .dark: return UIColor(red: 156 / 255, green: 163 / 255, blue: 175 / 255, alpha: 1)
        case .light: return UIColor(red: 100 / 255, green: 116 / 255, blue: 139 / 255, alpha: 1)
        }
    }

    static var success: UIColor {
        switch style {
        case .dark: return UIColor(red: 22 / 255, green: 163 / 255, blue: 74 / 255, alpha: 1)
        case .light: return UIColor(red: 21 / 255, green: 128 / 255, blue: 61 / 255, alpha: 1)
        }
    }

    static var failed: UIColor {
        switch style {
        case .dark: return UIColor(red: 225 / 255, green: 29 / 255, blue: 72 / 255, alpha: 1)
        case .light: return UIColor(red: 190 / 255, green: 18 / 255, blue: 60 / 255, alpha: 1)
        }
    }

    static var loading: UIColor {
        switch style {
        case .dark: return UIColor(red: 245 / 255, green: 158 / 255, blue: 11 / 255, alpha: 1)
        case .light: return UIColor(red: 180 / 255, green: 83 / 255, blue: 9 / 255, alpha: 1)
        }
    }

    static var accent: UIColor {
        UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1)
    }

    static var tabSelected: UIColor {
        switch style {
        case .dark: return UIColor(red: 55 / 255, green: 69 / 255, blue: 90 / 255, alpha: 0.9)
        case .light: return UIColor.white.withAlphaComponent(0.88)
        }
    }

    static var switchOn: UIColor {
        UIColor(red: 20 / 255, green: 83 / 255, blue: 45 / 255, alpha: 0.8)
    }

    static var buttonBackground: UIColor {
        switch style {
        case .dark: return UIColor(red: 31 / 255, green: 41 / 255, blue: 55 / 255, alpha: 0.8)
        case .light: return UIColor.white.withAlphaComponent(0.72)
        }
    }

    static var modeButtonBackground: UIColor {
        switch style {
        case .dark: return UIColor(red: 38 / 255, green: 50 / 255, blue: 63 / 255, alpha: 0.53)
        case .light: return UIColor(red: 226 / 255, green: 232 / 255, blue: 240 / 255, alpha: 0.72)
        }
    }

    static var modeButtonSelected: UIColor {
        switch style {
        case .dark: return UIColor(red: 55 / 255, green: 65 / 255, blue: 81 / 255, alpha: 0.8)
        case .light: return UIColor.white.withAlphaComponent(0.9)
        }
    }

    static var border: UIColor {
        switch style {
        case .dark: return UIColor.white.withAlphaComponent(0.09)
        case .light: return UIColor.black.withAlphaComponent(0.08)
        }
    }

    static var buttonBorder: UIColor {
        switch style {
        case .dark: return UIColor(red: 124 / 255, green: 133 / 255, blue: 148 / 255, alpha: 0.5)
        case .light: return UIColor(red: 71 / 255, green: 85 / 255, blue: 105 / 255, alpha: 0.30)
        }
    }

    static var buttonBorderActive: UIColor {
        switch style {
        case .dark: return UIColor(red: 209 / 255, green: 213 / 255, blue: 219 / 255, alpha: 0.8)
        case .light: return UIColor(red: 15 / 255, green: 23 / 255, blue: 42 / 255, alpha: 0.45)
        }
    }

    static var selectedControlText: UIColor {
        switch style {
        case .dark: return .white
        case .light: return textPrimary
        }
    }

    static var headerShadowColor: UIColor {
        switch style {
        case .dark: return .black
        case .light: return .white
        }
    }

    static var headerShadowOpacity: Float {
        switch style {
        case .dark: return 1
        case .light: return 0.9
        }
    }

    static var backgroundImageAlpha: CGFloat {
        switch style {
        case .dark: return 0.15
        case .light: return 0.18
        }
    }

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
        label.layer.shadowColor = headerShadowColor.cgColor
        label.layer.shadowOpacity = headerShadowOpacity
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
        imageView.alpha = AdsDebugTheme.backgroundImageAlpha
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
            AdsDebugTheme.style = UIImage.adsDebugFirstFrameLooksLight(url: url) ? .light : .dark
            backgroundColor = AdsDebugTheme.background
            imageView.alpha = AdsDebugTheme.backgroundImageAlpha
            imageView.image = UIImage.adsDebugAnimatedGIF(url: url)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension UIImage {
    static func adsDebugFirstFrameLooksLight(url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return false
        }
        return adsDebugAverageLuminance(cgImage: cgImage) > 0.58
    }

    static func adsDebugAverageLuminance(cgImage: CGImage) -> CGFloat {
        let width = 16
        let height = 16
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 0
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total: CGFloat = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = CGFloat(pixels[index]) / 255
            let g = CGFloat(pixels[index + 1]) / 255
            let b = CGFloat(pixels[index + 2]) / 255
            total += (0.299 * r) + (0.587 * g) + (0.114 * b)
        }
        return total / CGFloat(width * height)
    }

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
