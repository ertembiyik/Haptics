import UIKit
import PinLayout
import Resources

@available(iOS 15.0, *)
public final class LoaderFooterView: BaseCollectionSupplementaryView {

    private let spinner = ActivityView(frame: .zero)

    private let imageView = UIImageView(frame: .zero)

    private let titleLabel = UILabel(frame: .zero)

    private let subtitleLabel = UILabel(frame: .zero)

    private let button = SystemButton(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.spinner)
        self.addSubview(self.imageView)
        self.addSubview(self.titleLabel)
        self.addSubview(self.subtitleLabel)
        self.addSubview(self.button)

        self.setUpSpinner()
        self.setUpImageView()
        self.setUpTitleLabel()
        self.setUpSubtitleLabel()
        self.setUpButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        self.spinner.pin
            .center()
            .size(CGSize(width: 32, height: 32))

        self.imageView.pin
            .center()
            .marginTop(12)
            .size(CGSize(width: 35, height: 35))

        self.titleLabel.pin
            .below(of: self.imageView, aligned: .center)
            .marginTop(8)
            .sizeToFit()

        self.subtitleLabel.pin
            .below(of: self.titleLabel, aligned: .center)
            .sizeToFit()

        self.button.pin
            .below(of: self.subtitleLabel, aligned: .center)
            .marginTop(8)
            .size(CGSize(width: 101, height: 33))
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        self.spinner.isAnimating = self.window != nil
    }

    public override func apply(viewModel: SupplementaryViewModel) {
        guard let loaderViewModel = viewModel as? LoaderFooterViewModel else {
            return
        }

        self.register(cancellable: loaderViewModel.stateDataPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stateData in
                self?.didReceive(stateData: stateData)
            })

        self.didReceive(stateData: loaderViewModel.stateData)

        self.button.didTapHandler = { [weak loaderViewModel] _ in
            guard let loaderViewModel else {
                return
            }

            Task {
                try await loaderViewModel.stateData.refreshAction?()
            }
        }
    }

    private func setUpSpinner() {
        self.spinner.isUserInteractionEnabled = false
        self.spinner.tintColor = UIColor.res.white
        self.spinner.lineWidth = 4
    }

    private func setUpImageView() {
        let config = UIImage.SymbolConfiguration(hierarchicalColor: UIColor.res.red)
        self.imageView.image = UIImage.res.exclamationmarkTriangleFill
            .withConfiguration(config)
            .applyingSymbolConfiguration(.init(pointSize: 28))
        self.imageView.isUserInteractionEnabled = false
    }

    private func setUpTitleLabel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 20
        paragraph.maximumLineHeight = 20
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.label,
            .paragraphStyle: paragraph
        ]

        self.titleLabel.attributedText = NSAttributedString(string: String.res.somethingWentWrong,
                                                            attributes: attributes)
        self.titleLabel.isUserInteractionEnabled = false
    }

    private func setUpSubtitleLabel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 18
        paragraph.maximumLineHeight = 18
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular).rounded(),
            .foregroundColor: UIColor.res.secondaryLabel,
            .paragraphStyle: paragraph
        ]

        self.subtitleLabel.attributedText = NSAttributedString(string: String.res.errorSubtitle,
                                                               attributes: attributes)
        self.subtitleLabel.isUserInteractionEnabled = false
    }

    private func setUpButton() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 20
        paragraph.maximumLineHeight = 20
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold).rounded(),
            .foregroundColor: UIColor.res.white,
            .paragraphStyle: paragraph
        ]

        self.button.attributedText = NSAttributedString(string: String.res.errorStateRefreshButtonTitle,
                                                        attributes: attributes)
        self.button.backgroundColor = UIColor.res.systemGray6
        self.button.cornerRadius = 16
        self.button.layout = .centerImageLeadingTextTrailing(textMargin: 6)
        self.button.image = UIImage.res.arrowClockwise
            .withRenderingMode(.alwaysOriginal)
            .withTintColor(UIColor.res.white)

    }

    private func didReceive(stateData: LoaderFooterStateData) {
        self.button.didTapHandler = { _ in
            Task {
                try await stateData.refreshAction?()
            }
        }

        self.spinner.isHidden = !stateData.isLoading
        self.applyToErrorViews { view in
            view.isHidden = !stateData.hasError
        }

        self.spinner.alpha = stateData.isLoading ? 0 : 1
        self.applyToErrorViews { view in
            view.alpha = stateData.hasError ? 0 : 1
        }

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            self.spinner.alpha = stateData.isLoading ? 1 : 0
            self.applyToErrorViews { view in
                view.alpha = stateData.hasError ? 1 : 0
            }
        } completion: { _ in
            self.spinner.isHidden = !stateData.isLoading
            self.applyToErrorViews { view in
                view.isHidden = !stateData.hasError
            }

            self.setNeedsLayout()
        }
    }

    func applyToErrorViews(block: (UIView) -> Void) {
        [self.imageView, self.titleLabel, self.subtitleLabel, self.button].forEach { view in
            block(view)
        }
    }

}
