import UIKit
import PinLayout
import Dependencies
import OSLog
import UIComponents
import RemoteDataModels
import ConversationsSession

final class SendRequestController: UIViewController {

    private let skeletonEmojiInfoView = SkeletonEmojiInfoView(skeletonColor: UIColor.res.tertiarySystemBackground)

    private let emojiInfoView = EmojiInfoView(frame: .zero)

    private let sendRequestButton = LoaderButton(frame: .zero)

    private let ignoreButton = SystemButton(frame: .zero)

    private let viewModel: SendRequestViewModel

    @Dependency(\.authSession) private var authSession

    init(peerId: String) {
        self.viewModel = SendRequestViewModel(peerId: peerId)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.res.systemBackground

        self.view.addSubview(self.emojiInfoView)
        self.view.addSubview(self.skeletonEmojiInfoView)
        self.view.addSubview(self.sendRequestButton)
        self.view.addSubview(self.ignoreButton)

        self.setUpSendRequestButton()
        self.setUpIgnoreButton()

        if let task = self.viewModel.onStart() {
            self.awaitDataLoading(with: task)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.ignoreButton.pin
            .start(20)
            .end(20)
            .bottom(self.view.pin.safeArea.bottom)
            .height(54)

        self.sendRequestButton.pin
            .bottom(to: self.ignoreButton.edge.top)
            .marginBottom(16)
            .start(20)
            .end(20)
            .height(54)

        self.emojiInfoView.pin
            .top()
            .horizontally()
            .bottom(to: self.sendRequestButton.edge.top)

        self.skeletonEmojiInfoView.pin
            .top()
            .horizontally()
            .bottom(to: self.sendRequestButton.edge.top)
    }

    private func setUpSendRequestButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.black
        ]
        self.sendRequestButton.attributedText = NSAttributedString(string: String.res.sendRequestButtonTitle,
                                                                   attributes: attributes)


        self.sendRequestButton.backgroundColor = UIColor.res.white
        self.sendRequestButton.cornerRadius = 14
        self.sendRequestButton.layout = .centerText()
        self.sendRequestButton.isEnabled = false

        self.sendRequestButton.didTapHandler = { [weak self] _ in
            self?.didTapSendRequest()
        }
    }

    private func setUpIgnoreButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.white
        ]

        self.ignoreButton.attributedText = NSAttributedString(string: String.res.sendRequestIgnoreButtonTitle,
                                                              attributes: attributes)


        self.ignoreButton.backgroundColor = UIColor.res.quaternaryLabel
        self.ignoreButton.cornerRadius = 14
        self.ignoreButton.layout = .centerText()

        self.ignoreButton.didTapHandler = { [weak self] _ in
            self?.dismiss(animated: true)
        }
    }

    private func didTapSendRequest() {
        self.sendRequestButton.startLoading()

        let toastView = ToastView()

        Task {
            do {
                try await self.viewModel.sendRequest()

                await MainActor.run {
                    self.sendRequestButton.stopLoading()

                    toastView.update(with: .icon(predefinedIcon: .success, title: String.res.sendRequestSuccessTitle))
                }

                try? await Task.sleep(for: .seconds(3))

                await MainActor.run {
                    toastView.update(with: .hidden)
                }
            } catch where error is ConversationsSessionError {
                await MainActor.run {
                    self.sendRequestButton.stopLoading()
                }

                await self.showFullscreen(error: error)
            } catch {
                await MainActor.run {
                    self.sendRequestButton.stopLoading()
                }

                await self.show(error: error, with: toastView)
            }
        }
    }

    private func awaitDataLoading(with task: Task<RemoteDataModels.Profile, Error>) {
        Task {
            do {
                let profile = try await task.value

                await MainActor.run {
                    self.sendRequestButton.isEnabled = true
                    self.skeletonEmojiInfoView.isHidden = true

                    self.emojiInfoView.emoji = profile.emoji
                    self.emojiInfoView.title = String(format: String.res.sendRequestInfoTitle,
                                                      profile.name)
                    self.emojiInfoView.subtitle = String.res.sendRequestInfoSubtitle

                    self.emojiInfoView.setNeedsLayout()
                }
            } catch where error is SendRequestViewModelError {
                await self.showFullscreen(error: error)
            } catch {
                await self.show(error: error, with: ToastView())
            }
        }
    }

    private func show(error: Error, with toastView: ToastView) async {
        await MainActor.run {
            toastView.update(with: .icon(predefinedIcon: .failure, title: String.res.commonError, subtitle: error.localizedDescription))
        }

        try? await Task.sleep(for: .seconds(3))

        await MainActor.run {
            toastView.update(with: .hidden)
        }
    }

    private func showFullscreen(error: Error) async {
        await MainActor.run {
            self.sendRequestButton.isEnabled = false
            self.skeletonEmojiInfoView.isHidden = true

            self.emojiInfoView.emoji = "❌"
            self.emojiInfoView.title = String.res.commonError
            self.emojiInfoView.subtitle = error.localizedDescription

            self.emojiInfoView.setNeedsLayout()
        }
    }

}
