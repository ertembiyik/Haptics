import UIKit
import PinLayout
import Dependencies
import OSLog
import UIComponents
import LinksFactory

final class AddFriendsViewController: UIViewController {

    private let emojiInfoView = EmojiInfoView(frame: .zero)

    private let inviteFriendsButton = SystemButton(frame: .zero)

    @Dependency(\.authSession) private var authSession

    @Dependency(\.linksFactory) private var linksFactory

    @Dependency(\.analyticsSession) private var analyticsSession

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.res.black

        self.view.addSubview(self.emojiInfoView)
        self.view.addSubview(self.inviteFriendsButton)

        self.setUpEmojiInfoView()
        self.setUpInviteFriendsButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.emojiInfoView.pin
            .all()

        self.inviteFriendsButton.pin
            .start(20)
            .end(20)
            .bottom(self.view.pin.safeArea.bottom)
            .height(50)
    }

    private func setUpEmojiInfoView() {
        self.emojiInfoView.emoji = "👯"
        self.emojiInfoView.title = String.res.addFriendsTitle
        self.emojiInfoView.subtitle = String.res.addFriendsSubtitle
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
        self.inviteFriendsButton.cornerRadius = 11

        self.inviteFriendsButton.didTapHandler = { [weak self] _ in
            self?.didTapShare()
        }
    }

    private func didTapShare() {
        guard let userId = self.authSession.state.userId else {
            return
        }

        guard let profileLink = self.linksFactory.linkForUser(with: userId) else {
            Logger.root.error("Share action failed, could't generate link for user with uid: \(userId, privacy: .public)")

            return
        }

        let activityController = UIActivityViewController(activityItems: [profileLink],
                                                          applicationActivities: nil)

        activityController.popoverPresentationController?.sourceView = self.view

        activityController.completionWithItemsHandler = { [weak self] _, completed, _, _ in
            guard let self, completed else {
                return
            }

            self.analyticsSession.logShareInviteLink()
        }

        self.present(activityController, animated: true)
    }

}

