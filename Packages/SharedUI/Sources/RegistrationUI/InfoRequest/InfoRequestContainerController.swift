import UIKit
import UIComponents
import AuthSession
import Resources

public final class InfoRequestContainerController: CoreNavigationController {

    private let infoScopes: Set<AdditionalAuthInfoScope>

    private let viewModel: InfoRequestContainerViewModel

    public init(infoScopes: Set<AdditionalAuthInfoScope>) {
        self.infoScopes = infoScopes
        self.viewModel = InfoRequestContainerViewModel()

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.setUpSelf()

        if self.infoScopes.contains(.username) {
            let usernameRequestController = self.usernameRequestController()
            self.pushViewController(usernameRequestController, animated: true)
        } else if self.infoScopes.contains(.emoji) || self.infoScopes.contains(.name) {
            let emojiController = self.emojiRequestController()
            self.pushViewController(emojiController, animated: true)
        }
    }

    private func setUpSelf() {
        self.navigationBar.tintColor = UIColor.res.white
    }

    private func usernameRequestController() -> UIViewController {
        let infoRequestConfig = InfoRequestConfig(title: String.res.infoRequestUsernameTitle,
                                                  continueButtonTitle: String.res.infoRequestNextButtonTitle,
                                                  textFieldLeadingSymbol: "@",
                                                  placeholder: String.res.infoRequestUsernamePlaceholder) { [weak self] newUsername in

            guard let self else {
                return
            }

            try await self.viewModel.update(username: newUsername)

            await MainActor.run {
                if self.infoScopes.contains(.emoji) {
                    let emojiController = self.emojiRequestController()
                    self.pushViewController(emojiController, animated: true)
                } else {
                    self.viewModel.refreshAuthStateForCurrentUser()
                }
            }
        }

        return InfoRequestController(config: infoRequestConfig)
    }

    private func emojiRequestController() -> UIViewController {
        let infoRequestConfig = InfoRequestConfig(title: String.res.infoRequestEmojiTitle,
                                                  continueButtonTitle: String.res.infoRequestNextButtonTitle,
                                                  placeholder: String.res.infoRequestUsernamePlaceholder) { [weak self] newEmoji in

            guard let self else {
                return
            }

            try await self.viewModel.update(emoji: newEmoji)

            try await self.viewModel.updateName()

            self.viewModel.refreshAuthStateForCurrentUser()
        }

        return EmojiInfoRequestController(config: infoRequestConfig)
    }

}
