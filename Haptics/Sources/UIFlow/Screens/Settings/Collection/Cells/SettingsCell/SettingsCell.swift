import UIKit
import PinLayout
import OSLog
import Dependencies
import UIComponents

final class SettingsCell: BaseCollectionViewCell {

    private static func attributedTitle(from text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 19
        paragraphStyle.maximumLineHeight = 19
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private let containerControl = HighlightScaleControl(frame: .zero)

    private let iconContainer = UIView(frame: .zero)

    private let imageView = UIImageView(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let trailingImageView = UIImageView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.contentView.addSubview(self.containerControl)
        self.containerControl.addSubview(self.iconContainer)
        self.iconContainer.addSubview(self.imageView)
        self.containerControl.addSubview(self.titleLabel)
        self.containerControl.addSubview(self.trailingImageView)

        self.setUpSelf()
        self.setUpContainerControl()
        self.setUpIconContainer()
        self.setUpImageView()
        self.setUpTitleLabel()
        self.setUpTrailingImageView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.containerControl.pin
            .all()

        self.iconContainer.pin
            .centerStart(14)
            .size(CGSize(width: 28, height: 28))

        self.imageView.pin
            .center()
            .sizeToFit()

        self.titleLabel.pin
            .after(of: self.iconContainer, aligned: .center)
            .marginStart(12)
            .sizeToFit()

        self.trailingImageView.pin
            .centerEnd(14)
            .sizeToFit()
    }

    override func apply(viewModel: CellViewModel) {
        super.apply(viewModel: viewModel)

        guard let settingsViewModel = viewModel as? SettingsCellViewModel else {
            return
        }

        self.register(cancellable: settingsViewModel.settingsDataPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settingsData in
                self?.didReceive(settingsData: settingsData)
            })

        self.didReceive(settingsData: settingsViewModel.settingsData)

        self.containerControl.didTapHandler = { [weak settingsViewModel] _ in
            settingsViewModel?.didTap()
        }
    }

    private func setUpSelf() {
        self.backgroundColor = UIColor.res.clear
        self.contentView.layer.borderWidth = 1
        self.contentView.layer.borderColor = UIColor.res.tertiarySystemFill.cgColor
        self.contentView.layer.cornerRadius = 20
    }

    private func setUpContainerControl() {
        self.containerControl.highlightScaleFactor = 0.97
    }

    private func setUpIconContainer() {
        self.iconContainer.isUserInteractionEnabled = false
        self.iconContainer.clipsToBounds = true
        self.iconContainer.layer.cornerRadius = 8
    }

    private func setUpImageView() {
        self.imageView.isUserInteractionEnabled = false
        self.imageView.contentMode = .scaleAspectFit
    }

    private func setUpTitleLabel() {
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpTrailingImageView() {
        self.imageView.isUserInteractionEnabled = false
        self.imageView.contentMode = .scaleAspectFit
    }

    private func didReceive(settingsData: SettingsCellData?) {
        defer {
            self.setNeedsLayout()
        }

        guard let settingsData else {
            return
        }

        self.contentView.layer.maskedCorners = settingsData.roundedCorners
        self.imageView.image = settingsData.icon
        self.iconContainer.backgroundColor = settingsData.iconBackgroundColor
        self.titleLabel.attributedText = Self.attributedTitle(from: settingsData.title)
        self.trailingImageView.image = settingsData.trailingIcon
        self.trailingImageView.transform = settingsData.trailingIconRotation
    }

}
