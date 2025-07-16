import UIKit
import Combine
import PinLayout
import Dependencies
import OSLog
import UIComponents

final class SettingsProfileInfoHeaderView: BaseCollectionSupplementaryView {

    private static let emojiLabelControlSize = CGSize(width: 109, height: 109)

    private static let proIcon: UIImage = {
        let sizeConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)

        return UIImage.res.boltHeartFill
            .withConfiguration(sizeConfig)
    }()

    private let emojiLabelControl = HighlightScaleControl(frame: .zero)

    private let emojiLabel = UILabel(frame: .zero)

    private let titleContainerView = UIView(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let proImageView = UIImageView(frame: .zero)

    private let subtitleLabel = UILabel(frame: .zero)

    private let titleSkeletonLabel = UIView(frame: .zero)

    private let subtitleSkeletonLabel = UIView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.emojiLabelControl)
        self.emojiLabelControl.addSubview(self.emojiLabel)
        self.addSubview(self.titleContainerView)
        self.titleContainerView.addSubview(self.titleLabel)
        self.titleContainerView.addSubview(self.proImageView)
        self.addSubview(self.subtitleLabel)
        self.addSubview(self.titleSkeletonLabel)
        self.addSubview(self.subtitleSkeletonLabel)

        self.setUpEmojiLabelControl()
        self.setUpEmojiLabel()
        self.setUpTitleContainerView()
        self.setUpTitleLabel()
        self.setUpProImageView()
        self.setUpSubtitleLabel()
        self.setUpTitleSkeletonLabel()
        self.setUpSubtitleSkeletonLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.emojiLabelControl.pin
            .topCenter(32)
            .size(Self.emojiLabelControlSize)

        self.emojiLabel.pin
            .all()

        self.titleLabel.pin
            .sizeToFit()

        self.proImageView.pin
            .after(of: self.titleLabel, aligned: .center)
            .marginStart(4)
            .sizeToFit()

        self.titleContainerView.pin
            .below(of: self.emojiLabelControl, aligned: .center)
            .marginTop(16)
            .wrapContent()

        self.subtitleLabel.pin
            .below(of: self.titleContainerView, aligned: .center)
            .marginTop(4)
            .sizeToFit()

        self.titleSkeletonLabel.pin
            .below(of: self.emojiLabelControl, aligned: .center)
            .marginTop(16)
            .size(CGSize(width: 74, height: 41))

        self.subtitleSkeletonLabel.pin
            .below(of: self.titleSkeletonLabel, aligned: .center)
            .marginTop(4)
            .size(CGSize(width: 130, height: 19))
    }

    private func setUpEmojiLabelControl() {
        self.emojiLabelControl.layer.cornerRadius = Self.emojiLabelControlSize.width / 2
        self.emojiLabelControl.backgroundColor = UIColor.res.quaternarySystemFill
    }

    private func setUpEmojiLabel() {
        self.emojiLabel.font = UIFont.systemFont(ofSize: 64, weight: .bold).rounded()
        self.emojiLabel.textAlignment = .center
        self.emojiLabel.isUserInteractionEnabled = false
    }

    private func setUpTitleContainerView() {
        self.titleContainerView.isUserInteractionEnabled = false
    }

    private func setUpTitleLabel() {
        self.titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold).rounded()
        self.titleLabel.textAlignment = .center
        self.titleLabel.lineBreakMode = .byTruncatingMiddle
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpProImageView() {
        self.proImageView.isUserInteractionEnabled = false
        self.proImageView.contentMode = .scaleAspectFit
        self.proImageView.tintColor = UIColor.res.systemPink
    }

    private func setUpSubtitleLabel() {
        self.subtitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular).rounded()
        self.subtitleLabel.numberOfLines = 0
        self.subtitleLabel.textAlignment = .center
        self.subtitleLabel.textColor = UIColor.res.secondaryLabel
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpTitleSkeletonLabel() {
        self.titleSkeletonLabel.layer.cornerRadius = 8
        self.titleSkeletonLabel.backgroundColor = UIColor.res.quaternarySystemFill
        self.titleSkeletonLabel.isUserInteractionEnabled = false
    }

    private func setUpSubtitleSkeletonLabel() {
        self.subtitleSkeletonLabel.layer.cornerRadius = 4
        self.subtitleSkeletonLabel.backgroundColor = UIColor.res.quaternarySystemFill
        self.subtitleSkeletonLabel.isUserInteractionEnabled = false
    }

    override func apply(viewModel: any SupplementaryViewModel) {
        super.apply(viewModel: viewModel)

        guard let viewModel = viewModel as? SettingsProfileInfoHeaderViewModel else {
            return
        }

        self.register(cancellable: viewModel.profileHeaderDataPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profileHeaderData in
                self?.didReceive(profileInfoData: profileHeaderData)
            })

        self.didReceive(profileInfoData: viewModel.profileHeaderData)

        Task {
            do {
                try await viewModel.loadData()
            } catch {
                Logger.settings.error("Unable to get profile with error: \(error.localizedDescription, privacy: .public))")
            }
        }
    }

    private func didReceive(profileInfoData: SettingsProfileInfoHeaderData?) {
        defer {
            self.setNeedsLayout()
        }

        guard let profileInfoData else {
            self.titleSkeletonLabel.isHidden = false
            self.subtitleSkeletonLabel.isHidden = false

            self.emojiLabel.text = nil
            self.titleLabel.text = nil
            self.subtitleLabel.text = nil

            return
        }

        self.titleSkeletonLabel.isHidden = true
        self.subtitleSkeletonLabel.isHidden = true

        self.emojiLabel.text = profileInfoData.profile.emoji
        self.titleLabel.text = profileInfoData.profile.name
        self.proImageView.image = profileInfoData.isPro ? Self.proIcon : nil
        self.subtitleLabel.text = "@" + profileInfoData.profile.username
    }

}
