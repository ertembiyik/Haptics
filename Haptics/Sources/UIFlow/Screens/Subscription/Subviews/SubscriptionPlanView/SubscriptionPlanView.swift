import UIKit
import UIComponents
import Resources
import PinLayout

final class SubscriptionPlanView: HighlightScaleControl {

    private static let baseLeadingMargin: CGFloat = 18

    private static func attributedTitle(from text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 25
        paragraph.maximumLineHeight = 25
        paragraph.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 21, weight: .bold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func attributedPrice(from text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 19
        paragraph.maximumLineHeight = 19
        paragraph.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func attributedPrimarySubtitle(from text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 15
        paragraph.maximumLineHeight = 15
        paragraph.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold).rounded(),
            .foregroundColor: UIColor.res.systemPink,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func attributedSecondarySubtitle(from text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 15
        paragraph.maximumLineHeight = 15
        paragraph.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.tertiaryLabel,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func attributedDiscountTitle(from text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 15
        paragraph.maximumLineHeight = 15
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func attributedCurrentPlanSubtitle(from text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 15
        paragraph.maximumLineHeight = 15
        paragraph.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold).rounded(),
            .foregroundColor: UIColor.res.systemBlue,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    override var isSelected: Bool {
        didSet {
            self.containerView.layer.borderColor = self.isSelected ? UIColor.res.white.cgColor : nil
            self.containerView.layer.borderWidth = self.isSelected ? 2 : 0
        }
    }

    var config: SubscriptionPlanConfig? {
        didSet {
            self.updateConfig()
        }
    }

    private let containerView = UIView(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let priceLabel = UILabel(frame: .zero)

    private let primarySubtitleLabel = UILabel(frame: .zero)

    private let secondarySubtitleLabel = UILabel(frame: .zero)

    private let currentPlanSubtitleLabel = UILabel(frame: .zero)

    private let discountLabelContainerView = UIView(frame: .zero)

    private let discountLabel = UILabel(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.containerView)
        self.containerView.addSubview(self.titleLabel)
        self.containerView.addSubview(self.priceLabel)
        self.containerView.addSubview(self.primarySubtitleLabel)
        self.containerView.addSubview(self.secondarySubtitleLabel)
        self.containerView.addSubview(self.currentPlanSubtitleLabel)
        self.addSubview(self.discountLabelContainerView)
        self.discountLabelContainerView.addSubview(self.discountLabel)

        self.setUpContainerView()
        self.setUpSelf()
        self.setUpTitleLabel()
        self.setUpPriceLabel()
        self.setUpPrimarySubtitleLabel()
        self.setUpSecondarySubtitleLabel()
        self.setUpCurrentPlanSubtitleLabel()
        self.setUpDiscountLabelContainerView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.containerView.pin
            .all()

        self.titleLabel.pin
            .sizeToFit()
            .top(20)
            .horizontally(Self.baseLeadingMargin)

        self.priceLabel.pin
            .sizeToFit()
            .below(of: self.titleLabel)
            .marginTop(8)
            .horizontally(Self.baseLeadingMargin)

        self.primarySubtitleLabel.pin
            .sizeToFit()
            .below(of: self.priceLabel)
            .marginTop(6)
            .horizontally(Self.baseLeadingMargin)

        self.currentPlanSubtitleLabel.pin
            .sizeToFit()
            .below(of: self.primarySubtitleLabel)
            .marginTop(6)
            .horizontally(Self.baseLeadingMargin)

        self.secondarySubtitleLabel.pin
            .sizeToFit()
            .below(of: self.currentPlanSubtitleLabel)
            .marginTop(6)
            .horizontally(Self.baseLeadingMargin)

        self.discountLabel.pin
            .sizeToFit()
            .center()

        self.discountLabelContainerView.pin
            .wrapContent(.all, padding: PEdgeInsets(top: 6, left: 10, bottom: 4, right: 10))
            .center(to: self.anchor.topCenter)

        self.discountLabelContainerView.layer.cornerRadius = self.discountLabelContainerView.bounds.height / 2
    }

    private func setUpSelf() {
        self.backgroundColor = UIColor.res.clear
    }

    private func setUpContainerView() {
        self.containerView.backgroundColor = UIColor.res.white.withAlphaComponent(0.12)
        self.containerView.layer.cornerRadius = 24
        self.containerView.isUserInteractionEnabled = false
    }

    private func setUpTitleLabel() {
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpPriceLabel() {
        self.priceLabel.isUserInteractionEnabled = false
    }

    private func setUpPrimarySubtitleLabel() {
        self.primarySubtitleLabel.isUserInteractionEnabled = false
    }

    private func setUpSecondarySubtitleLabel() {
        self.secondarySubtitleLabel.isUserInteractionEnabled = false
        self.secondarySubtitleLabel.attributedText = Self.attributedSecondarySubtitle(from: String.res.subscriptionCancelAnyTime)
    }

    private func setUpCurrentPlanSubtitleLabel() {
        self.currentPlanSubtitleLabel.isUserInteractionEnabled = false
    }

    private func setUpDiscountLabelContainerView() {
        self.discountLabelContainerView.backgroundColor = UIColor.res.systemPink
        self.discountLabelContainerView.isUserInteractionEnabled = false
    }

    private func setUpDiscountLabel() {
        self.discountLabel.isUserInteractionEnabled = false
    }

    private func updateConfig() {
        defer {
            self.setNeedsLayout()
        }

        guard let config else {
            self.titleLabel.attributedText = nil
            self.primarySubtitleLabel.attributedText = nil
            self.secondarySubtitleLabel.attributedText = nil
            self.currentPlanSubtitleLabel.attributedText = nil
            self.discountLabel.attributedText = nil

            return
        }

        self.titleLabel.attributedText = Self.attributedTitle(from: config.title)

        switch config.subtitleConfig {
        case .select(price: let price):
            self.priceLabel.attributedText = Self.attributedPrice(from: price)
            self.primarySubtitleLabel.attributedText = nil
            self.currentPlanSubtitleLabel.attributedText = nil
        case .currentPlan(price: let price):
            self.priceLabel.attributedText = Self.attributedPrice(from: price)
            self.primarySubtitleLabel.attributedText = nil
            self.currentPlanSubtitleLabel.attributedText = Self.attributedCurrentPlanSubtitle(from: String.res.subscriptionCurrentPlan)
        case .trialAvailable(price: let price, trial: let trial):
            self.priceLabel.attributedText = Self.attributedPrice(from: price)
            self.primarySubtitleLabel.attributedText = Self.attributedPrimarySubtitle(from: trial)
            self.currentPlanSubtitleLabel.attributedText = nil
        }

        if let discountPercent = config.discountPercent {
            self.discountLabelContainerView.isHidden = false
            self.discountLabel.attributedText = Self.attributedDiscountTitle(from: "-\(discountPercent)%")
        } else {
            self.discountLabelContainerView.isHidden = true
            self.discountLabel.attributedText = nil
        }
    }

}
