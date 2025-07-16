import UIKit
import SafariServices
import PinLayout
import OSLog
import UIComponents
import UIKitPrivateExtensions
import Dependencies
import LinksFactory
import AuthSession

class WelcomeViewController: UIViewController, LinkLabelDelegate {

    private let centerContainerView = UIView(frame: .zero)

    private let logoImageView = UIImageView(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let continueWithAppleButton = LoaderButton(frame: .zero)

    private let legalLabel = LinkLabel(frame: .zero)

    @Dependency(\.linksFactory) private var linksFactory

    @Dependency(\.authSession) private var authSession
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.centerContainerView)
        self.centerContainerView.addSubview(self.logoImageView)
        self.centerContainerView.addSubview(self.titleLabel)
        self.view.addSubview(self.continueWithAppleButton)
        self.view.addSubview(self.legalLabel)

        self.setUpSelf()
        self.setUpLogoImageView()
        self.setUpTitleLabel()
        self.setUpContinueWithAppleButton()
        self.setUpLegalLabel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.logoImageView.pin
            .size(CGSize(width: 256, height: 256))
            .top()

        self.titleLabel.pin
            .below(of: self.logoImageView, aligned: .center)
            .marginTop(20)
            .sizeToFit()

        self.centerContainerView.pin
            .wrapContent()
            .center()

        let marginHorizontal: CGFloat = 20

        self.legalLabel.pin
            .sizeToFit(.width)
            .bottom(self.view.pin.safeArea.bottom)
            .horizontally(marginHorizontal)

        self.continueWithAppleButton.pin
            .above(of: self.legalLabel)
            .marginBottom(12)
            .horizontally(marginHorizontal)
            .height(58)
    }

    // MARK: - LinkLabelDelegate

    func labelDidDetectLink(_ label: LinkLabel, link: URL) {
        if link.path == "license" {
            let controller = SFSafariViewController(url: self.linksFactory.termsOfService())
            self.present(controller, animated: true)
        } else if link.path == "policy" {
            let controller = SFSafariViewController(url: self.linksFactory.privacyPolicy())
            self.present(controller, animated: true)
        }
    }

    // MARK: - Set Up
    
    private func setUpSelf() {
        self.view.backgroundColor = UIColor.res.black
    }

    private func setUpLogoImageView() {
        self.logoImageView.image = UIImage.res.heart
    }

    private func setUpTitleLabel() {
        self.titleLabel.text = String.res.welcomeTitle
        self.titleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold).rounded()
        self.titleLabel.textColor = UIColor.res.label
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0
    }

    private func setUpContinueWithAppleButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.label
        ]
        self.continueWithAppleButton.attributedText = NSAttributedString(string: String.res.welcomeButtonTitle,
                                                                         attributes: attributes)

        let image = UIImage.res.appleLogo
            .withRenderingMode(.alwaysOriginal)
            .withTintColor(UIColor.res.label)
        self.continueWithAppleButton.image = image

        self.continueWithAppleButton.backgroundColor = UIColor.res.white.withAlphaComponent(0.12)
        self.continueWithAppleButton.cornerRadius = 14
        self.continueWithAppleButton.layout = .centerImageLeadingTextTrailing(textMargin: 8)
        self.continueWithAppleButton.spinnerTintColor = UIColor.res.label

        self.continueWithAppleButton.didTapHandler = { [weak self] _ in
            guard let self else {
                return
            }

            self.continueWithAppleButton.startLoading()

            Task {
                do {
                    try await self.authSession.signIn()

                    await MainActor.run {
                        self.continueWithAppleButton.stopLoading()
                    }
                } catch {
                    await MainActor.run {
                        self.continueWithAppleButton.stopLoading()
                    }

                    Logger.auth.error("Error authenticating with apple: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func setUpLegalLabel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 15
        paragraph.maximumLineHeight = 15
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium).rounded(),
            .foregroundColor: UIColor.res.secondaryLabel,
            .paragraphStyle: paragraph
        ]

        let attributedString = NSMutableAttributedString(string: String.res.welcomeConfirmPolicy,
                                                         attributes: attributes)

        attributedString.detectLinks(with: .link, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: UIColor.res.tertiaryLabel,
            .paragraphStyle: paragraph,
            .underlineColor: UIColor.res.tertiaryLabel.withAlphaComponent(0.5),
        ])

        self.legalLabel.numberOfLines = 0
        self.legalLabel.delegate = self
        self.legalLabel.isUserInteractionEnabled = true

        self.legalLabel.attributedText = attributedString
    }

}
