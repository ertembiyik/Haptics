import UIKit
import PinLayout
import OSLog
import UIComponents
import Resources

public final class ForceUpdateViewController: UIViewController {

    private let emojiInfoView = EmojiInfoView(frame: .zero)

    private let updateAppButton = SystemButton(frame: .zero)

    private let appLink: String

    public init(appLink: String) {
        self.appLink = appLink

        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        self.isModalInPresentation = true

        self.view.backgroundColor = UIColor.res.systemBackground

        self.view.addSubview(self.emojiInfoView)
        self.view.addSubview(self.updateAppButton)

        self.setUpEmojiInfoView()
        self.setUpUpdateAppButton()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.updateAppButton.pin
            .start(20)
            .end(20)
            .bottom(self.view.pin.safeArea.bottom)
            .height(50)

        self.emojiInfoView.pin
            .top()
            .horizontally()
            .bottom(to: self.updateAppButton.edge.top)
    }

    private func setUpEmojiInfoView() {
        self.emojiInfoView.emoji = "🫦"
        self.emojiInfoView.title = String.res.forceUpdateTitle
        self.emojiInfoView.subtitle = String.res.forceUpdateSubtitle
    }

    private func setUpUpdateAppButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.res.black
        ]

        self.updateAppButton.attributedText = NSAttributedString(string: String.res.forceUpdateButtonTitle,
                                                                 attributes: attributes)


        self.updateAppButton.backgroundColor = UIColor.res.white
        self.updateAppButton.layout = .centerText()
        self.updateAppButton.cornerRadius = 11

        self.updateAppButton.didTapHandler = { [weak self] _ in
            guard let self else {
                return
            }

            Task {
                do {
                    try await self.openAppLink()
                } catch {
                    Logger.forceUpdate.error("Unable to open app url: \(self.appLink, privacy: .public), error: \(error.localizedDescription)")

                    await self.show(error: error)
                }
            }
        }
    }

    private func openAppLink() async throws {
        let url: URL?

        if #available(iOS 17.0, *) {
            url = URL(string: self.appLink, encodingInvalidCharacters: false)
        } else {
            url = URL(string: self.appLink)
        }

        guard let url else {
            throw ForceUpdateError.invalidUrl
        }

        await MainActor.run {
            UIApplication.shared.open(url)
        }
    }

    private func show(error: Error) async {
        let toastView = ToastView()

        await MainActor.run {
            toastView.update(with: .icon(predefinedIcon: .failure, title: String.res.commonError, subtitle: error.localizedDescription))
        }

        if #available(iOS 16.0, *) {
            try? await Task.sleep(for: .seconds(3))
        } else {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        await MainActor.run {
            toastView.update(with: .hidden)
        }
    }

}

