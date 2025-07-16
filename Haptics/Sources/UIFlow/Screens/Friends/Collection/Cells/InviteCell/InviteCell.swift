import UIKit
import PinLayout
import OSLog
import Dependencies
import UIComponents

final class InviteCell: BaseCollectionViewCell {

    private static let baseLabelHeight: CGFloat = 19

    private static func attributedTitle(from text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = Self.baseLabelHeight
        paragraphStyle.maximumLineHeight = Self.baseLabelHeight
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func attributedSubtitle(from text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = Self.baseLabelHeight
        paragraphStyle.maximumLineHeight = Self.baseLabelHeight
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .medium).rounded(),
            .foregroundColor: UIColor.res.tertiaryLabel,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private let titleLabel = UILabel(frame: .zero)

    private let subtitleLabel = UILabel(frame: .zero)

    private let progressView = ProgressView(frame: .zero)

    private let joinedLabel = UILabel(frame: .zero)

    private let moreToJoinLabel = UILabel(frame: .zero)

    private let inviteFriendsButton = SystemButton(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.subtitleLabel)
        self.contentView.addSubview(self.progressView)
        self.contentView.addSubview(self.joinedLabel)
        self.contentView.addSubview(self.moreToJoinLabel)
        self.contentView.addSubview(self.inviteFriendsButton)

        self.setUpSelf()
        self.setUpTitleLabel()
        self.setUpSubtitleLabel()
        self.setUpProgressView()
        self.setUpJoinedLabel()
        self.setUpMoreToJoinLabel()
        self.setUpInviteFriendsButton()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.titleLabel.pin
            .topCenter(20)
            .sizeToFit()
            .marginHorizontal(18)

        self.subtitleLabel.pin
            .below(of: self.titleLabel, aligned: .center)
            .marginTop(8)
            .sizeToFit()
            .marginHorizontal(18)

        self.progressView.pin
            .below(of: self.subtitleLabel)
            .marginTop(20)
            .height(12)
            .horizontally(18)

        self.joinedLabel.pin
            .marginTop(8)
            .below(of: self.progressView, aligned: .start)
            .sizeToFit()

        self.moreToJoinLabel.pin
            .marginTop(8)
            .below(of: self.progressView, aligned: .end)
            .sizeToFit()

        self.inviteFriendsButton.pin
            .below(of: self.joinedLabel)
            .marginTop(20)
            .horizontally(18)
            .height(46)
            .marginBottom(20)
    }

    override func apply(viewModel: CellViewModel) {
        super.apply(viewModel: viewModel)

        guard let viewModel = viewModel as? InviteCellViewModel else {
            return
        }

        self.register(cancellable: viewModel.inviteDataPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inviteData in
                self?.didReceive(inviteData: inviteData)
            })

        self.didReceive(inviteData: viewModel.inviteData)
    }

    private func setUpSelf() {
        self.contentView.backgroundColor = UIColor.res.tertiarySystemBackground
        self.contentView.layer.cornerRadius = 24
    }

    private func setUpTitleLabel() {
        self.titleLabel.isUserInteractionEnabled = false
        self.titleLabel.numberOfLines = 0
        self.titleLabel.attributedText = Self.attributedTitle(from: String.res.friendsFreeEmojiTitle)
    }

    private func setUpSubtitleLabel() {
        @Dependency(\.toggleSession) var toggleSession

        self.subtitleLabel.isUserInteractionEnabled = false
        self.subtitleLabel.numberOfLines = 0
        self.subtitleLabel.attributedText = Self.attributedSubtitle(from: "Bring \(toggleSession.freeEmojisInvitesCount) friends to get emoji mode for free")
    }

    private func setUpProgressView() {
        self.progressView.backgroundColor = UIColor.res.quaternaryLabel
        self.progressView.progressColor = UIColor.res.systemBlue
        self.progressView.isUserInteractionEnabled = false
        self.progressView.layer.cornerRadius = 6
    }

    private func setUpJoinedLabel() {
        self.joinedLabel.isUserInteractionEnabled = false
        self.joinedLabel.numberOfLines = 0
        self.joinedLabel.textColor = UIColor.res.systemBlue
        self.joinedLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold).rounded()
    }

    private func setUpMoreToJoinLabel() {
        self.moreToJoinLabel.isUserInteractionEnabled = false
        self.moreToJoinLabel.numberOfLines = 0
        self.moreToJoinLabel.textColor = UIColor.res.tertiaryLabel
        self.moreToJoinLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold).rounded()
    }

    private func setUpInviteFriendsButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.black
        ]

        self.inviteFriendsButton.attributedText = NSAttributedString(string: String.res.inviteFriendsButtonTitle,
                                                                     attributes: attributes)


        self.inviteFriendsButton.backgroundColor = UIColor.res.white
        self.inviteFriendsButton.layout = .centerText()
        self.inviteFriendsButton.cornerRadius = 14

        self.inviteFriendsButton.didTapHandler = { [weak self] _ in
            guard let viewModel = self?.lastAppliedViewModel as? InviteCellViewModel else {
                return
            }

            viewModel.didTapShare()
        }
    }

    private func didReceive(inviteData: InviteCellData) {
        self.progressView.set(progress: CGFloat(inviteData.current) / CGFloat(inviteData.target), animated: true)
        self.joinedLabel.text = "\(inviteData.current) joined"
        self.moreToJoinLabel.text = "\(inviteData.target - inviteData.current) more left"

        self.setNeedsLayout()
    }

}
