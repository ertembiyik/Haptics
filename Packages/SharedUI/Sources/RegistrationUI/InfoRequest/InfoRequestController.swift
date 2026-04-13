import UIKit
import PinLayout
import Combine
import OSLog
import Dependencies
import UIComponents

final class InfoRequestController: UIViewController, UITextFieldDelegate {

    private var cancellables = Set<AnyCancellable>()

    private var keyboardHeight: CGFloat?

    private let config: InfoRequestConfig

    private let titleLabel = UILabel(frame: .zero)

    private let textField = UITextField(frame: .zero)

    private let continueButton = LoaderButton(frame: .zero)

    init(config: InfoRequestConfig) {
        self.config = config

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.titleLabel)
        self.view.addSubview(self.textField)
        self.view.addSubview(self.continueButton)
        
        self.setUpSelf()
        self.setUpTitleLabel()
        self.setUpTextField()
        self.setUpContinueButton()

        self.observeKeyboard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.textField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.textField.resignFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let baseMargin: CGFloat = 20

        self.titleLabel.pin
            .start(baseMargin)
            .top(self.view.pin.safeArea.top + baseMargin)
            .end(baseMargin)
            .height(41)

        self.textField.pin
            .below(of: self.titleLabel)
            .marginTop(16)
            .start(baseMargin)
            .end(baseMargin)
            .height(54)

        if let keyboardHeight {
            self.continueButton.pin
                .bottom(keyboardHeight + baseMargin)
                .start(baseMargin)
                .end(baseMargin)
                .height(54)
        } else {
            self.continueButton.pin
                .bottom(self.view.pin.safeArea.bottom + baseMargin)
                .start(baseMargin)
                .end(baseMargin)
                .height(54)
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.didComplete()
        
        return false
    }

    private func setUpSelf() {
        self.view.backgroundColor = UIColor.res.black
        self.navigationItem.backButtonDisplayMode = .minimal
    }

    private func setUpTitleLabel() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold).rounded(),
            .kern: -0.4,
            .foregroundColor: UIColor.res.white
        ]

        self.titleLabel.attributedText = NSAttributedString(string: self.config.title,
                                                            attributes: attributes)
    }

    private func setUpTextField() {
        let placeholderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .kern: -0.4,
            .foregroundColor: UIColor.res.quaternaryLabel
        ]

        self.textField.attributedPlaceholder = NSAttributedString(string: self.config.placeholder,
                                                                  attributes: placeholderAttributes)

        let typingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .kern: -0.4,
            .foregroundColor: UIColor.res.white
        ]

        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .none
        self.textField.typingAttributes = typingAttributes
        self.textField.tintColor = UIColor.res.white
        self.textField.backgroundColor = UIColor.res.systemGray6
        self.textField.layer.cornerRadius = 14
        self.textField.leftViewMode = .always
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)

        let container = UIView(
            frame: CGRect(
                origin: CGPoint(x: 0, y: 16),
                size: CGSize(width: 36, height: 22)
            )
        )

        if let leadingSymbol = self.config.textFieldLeadingSymbol {
            let label = UILabel(
                frame: CGRect(
                    origin: CGPoint(x: 16, y: 0),
                    size: CGSize(width: 16, height: 22)
                )
            )

            label.attributedText = NSAttributedString(string: leadingSymbol,
                                                      attributes: typingAttributes)

            container.addSubview(label)
        }

        self.textField.leftView = container
    }

    private func setUpContinueButton() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .kern: -0.4,
            .foregroundColor: UIColor.res.black
        ]

        self.continueButton.attributedText = NSAttributedString(string: self.config.continueButtonTitle,
                                                                attributes: attributes)

        self.continueButton.backgroundColor = UIColor.res.label
        self.continueButton.cornerRadius = 14
        self.continueButton.layout = .centerText()

        self.updateContinueButton(with: false, animated: false)

        self.continueButton.didTapHandler = { [weak self] _ in
            guard let self else {
                return
            }

            self.didComplete()
        }
    }

    private func updateContinueButton(with isEnabled: Bool, animated: Bool) {
        let performChanges: () -> Void = {
            self.continueButton.isEnabled = isEnabled
            self.continueButton.alpha = isEnabled ? 1 : 0.3
        }

        guard animated else {
            performChanges()
            return
        }

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            performChanges()
        }
    }

    private func observeKeyboard() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
                let animationDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                    return
                }

                self.keyboardHeight = keyboardSize.height

                UIView.animate(withDuration: animationDuration) {
                    self.continueButton.pin
                        .bottom(keyboardSize.height + 20)
                }
            }
            .store(in: &self.cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                let animationDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
                    return
                }

                self.keyboardHeight = nil

                UIView.animate(withDuration: animationDuration) {
                    self.continueButton.pin
                        .bottom(self.view.pin.safeArea.bottom + 20)
                }
            }
            .store(in: &self.cancellables)
    }

    @objc
    private func textFieldDidChange(_ textField: UITextField) {
        let isEnabled = textField.text?.isEmpty == false
        self.updateContinueButton(with: isEnabled, animated: true)
    }

    private func didComplete() {
        guard let value = self.textField.text else {
            return
        }

        self.continueButton.startLoading()
        self.textField.resignFirstResponder()

        Task {
            do {
                try await self.config.completion(value)

                await MainActor.run {
                    self.continueButton.stopLoading()
                }
            } catch {
                await self.show(error: error, with: ToastView())

                await MainActor.run {
                    self.continueButton.stopLoading()
                }

                Logger.auth.error("Error executing auth info request: \(error.localizedDescription, privacy: .public)")
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
}
