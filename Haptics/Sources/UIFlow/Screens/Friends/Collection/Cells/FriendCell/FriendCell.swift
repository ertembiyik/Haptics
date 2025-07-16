import UIKit
import PinLayout
import OSLog
import Dependencies
import UIComponents

final class FriendCell: BaseCollectionViewCell {

    private static let emojiLabelSize = CGSize(width: 48, height: 48)

    private static let buttonSize = CGSize(width: 30, height: 30)

    private static let baseLabelMargin: CGFloat = 10

    private static let baseLabelHeight: CGFloat = 19

    private static func attributedName(from text: String) -> NSAttributedString {
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

    private static func attributedUsername(from text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = Self.baseLabelHeight
        paragraphStyle.maximumLineHeight = Self.baseLabelHeight
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .medium).rounded(),
            .foregroundColor: UIColor.res.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private var lastAppliedViewModelUid: String?

    private let emojiLabelContainer = UIView(frame: .zero)

    private let labelsContainer = UIView(frame: .zero)

    private let emojiLabel = UILabel(frame: .zero)

    private let nameLabel = UILabel(frame: .zero)

    private let usernameLabel = UILabel(frame: .zero)

    private let skeletonLabel = UIView(frame: .zero)

    private let acceptButton = SystemButton(frame: .zero)

    private let moreButton = SystemButton(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.contentView.addSubview(self.emojiLabelContainer)
        self.emojiLabelContainer.addSubview(self.emojiLabel)
        self.contentView.addSubview(self.labelsContainer)
        self.labelsContainer.addSubview(self.nameLabel)
        self.labelsContainer.addSubview(self.usernameLabel)
        self.labelsContainer.addSubview(self.skeletonLabel)
        self.contentView.addSubview(self.acceptButton)
        self.contentView.addSubview(self.moreButton)

        self.setUpSelf()
        self.setUpEmojiLabelContainer()
        self.setUpEmojiLabel()
        self.setUpSkeletonLabel()
        self.setUpAddButton()
        self.setUpMoreButton()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.emojiLabelContainer.pin
            .centerStart()
            .size(Self.emojiLabelSize)

        self.emojiLabel.pin
            .all()

        guard let friendViewModel = self.lastAppliedViewModel as? FriendCellViewModel else {
            return
        }

        let needsDoubleButtonMargin = friendViewModel.needsAcceptButton

        let labelWidth: CGFloat = self.bounds.width
        - Self.emojiLabelSize.width
        - Self.baseLabelMargin * (needsDoubleButtonMargin ? 4 : 2)
        - Self.buttonSize.width * (needsDoubleButtonMargin ? 2 : 1)

        self.nameLabel.pin
            .topStart()
            .height(Self.baseLabelHeight)
            .width(labelWidth)

        self.usernameLabel.pin
            .below(of: self.nameLabel, aligned: .start)
            .marginTop(2)
            .height(Self.baseLabelHeight)
            .width(labelWidth)

        self.skeletonLabel.pin
            .centerStart()
            .size(CGSize(width: 25, height: 15))

        self.labelsContainer.pin
            .after(of: self.emojiLabelContainer, aligned: .center)
            .marginStart(10)
            .wrapContent()

        self.moreButton.pin
            .centerEnd()
            .size(Self.buttonSize)

        if friendViewModel.needsAcceptButton {
            self.acceptButton.pin
                .before(of: self.moreButton, aligned: .center)
                .marginEnd(Self.baseLabelMargin)
                .size(Self.buttonSize)
        }

    }

    override func apply(viewModel: CellViewModel) {
        super.apply(viewModel: viewModel)

        guard let friendViewModel = viewModel as? FriendCellViewModel else {
            return
        }

        self.lastAppliedViewModelUid = friendViewModel.uid

        self.acceptButton.isHidden = !friendViewModel.needsAcceptButton

        self.register(cancellable: friendViewModel.friendDataPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] friendData in
                self?.didReceive(friendData: friendData)
            })

        self.didReceive(friendData: friendViewModel.friendData)

        self.acceptButton.didTapHandler = { [weak friendViewModel] _ in
            friendViewModel?.didTapAccept()
        }

        self.moreButton.menuConfiguration = UIContextMenuConfiguration(identifier: nil,
                                                                       previewProvider: nil) { [weak friendViewModel] _ in
            return FriendContextMenuFabric.contextMenu { [weak friendViewModel] in
                friendViewModel?.blockUser()
            } reportDidTapHandler: { [weak friendViewModel] issue, subIssue in
                friendViewModel?.reportUser(with: issue, and: subIssue)
            } removeDidTapHandler: { [weak friendViewModel] in
                friendViewModel?.didTapDeny()
            }
        }

        Task {
            do {
                try await friendViewModel.loadData()
            } catch {
                Logger.friends.error("Error loading friend data: \(error.localizedDescription)")
            }
        }
    }

    private func setUpSelf() {
        self.backgroundColor = UIColor.res.clear
    }

    private func setUpEmojiLabelContainer() {
        self.emojiLabelContainer.backgroundColor = UIColor.res.tertiarySystemBackground
        self.emojiLabelContainer.layer.cornerRadius = Self.emojiLabelSize.width / 2
        self.emojiLabelContainer.clipsToBounds = true
        self.emojiLabelContainer.isUserInteractionEnabled = false
    }

    private func setUpEmojiLabel() {
        self.emojiLabel.isUserInteractionEnabled = false
        self.emojiLabel.clipsToBounds = true
        self.emojiLabel.textAlignment = .center
        self.emojiLabel.font = UIFont.systemFont(ofSize: 16).rounded()
    }

    private func setUpSkeletonLabel() {
        self.skeletonLabel.layer.cornerRadius = 4
        self.skeletonLabel.isUserInteractionEnabled = false
        self.skeletonLabel.backgroundColor = UIColor.res.systemGray5
    }

    private func setUpAddButton() {
        let config = UIImage.SymbolConfiguration(font: UIFont.systemFont(ofSize: 16, weight: .black).rounded())
        let image = UIImage.res.plus.withConfiguration(config)
            .withRenderingMode(.alwaysOriginal)
            .withTintColor(UIColor.res.systemGray5)

        self.acceptButton.image = image
        self.acceptButton.backgroundColor = UIColor.res.white
        self.acceptButton.layout = .centerImage()
        self.acceptButton.layer.cornerRadius = Self.buttonSize.width / 2
    }

    private func setUpMoreButton() {
        let config = UIImage.SymbolConfiguration(font: UIFont.systemFont(ofSize: 16, weight: .black).rounded())
        let image = UIImage.res.ellipsis.withConfiguration(config)
            .withRenderingMode(.alwaysOriginal)
            .withTintColor(UIColor.res.systemGray5)

        self.moreButton.image = image
        self.moreButton.backgroundColor = UIColor.res.white
        self.moreButton.layout = .centerImage()
        self.moreButton.layer.cornerRadius = Self.buttonSize.width / 2
        self.moreButton.isContextMenuInteractionEnabled = true
        self.moreButton.showsMenuAsPrimaryAction = true
    }

    private func didReceive(friendData: FriendCellData?) {
        defer {
            self.setNeedsLayout()
        }

        guard let friendData, self.lastAppliedViewModelUid == self.lastAppliedViewModel?.uid else {
            self.skeletonLabel.isHidden = false
            self.skeletonLabel.alpha = 1

            self.nameLabel.isHidden = true
            self.nameLabel.alpha = 0

            self.usernameLabel.isHidden = true
            self.usernameLabel.alpha = 0

            self.emojiLabel.isHidden = true
            self.emojiLabel.alpha = 0
            return
        }

        self.skeletonLabel.isHidden = true
        self.skeletonLabel.alpha = 0

        self.nameLabel.isHidden = false
        self.nameLabel.alpha = 1

        self.usernameLabel.isHidden = false
        self.usernameLabel.alpha = 1

        self.emojiLabel.isHidden = false
        self.emojiLabel.alpha = 1

        self.nameLabel.attributedText = Self.attributedName(from: friendData.peer.name)
        self.usernameLabel.attributedText = Self.attributedUsername(from: "@" + friendData.peer.username)
        self.emojiLabel.text = friendData.peer.emoji
    }

}
