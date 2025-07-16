import UIKit
import PinLayout
import Resources

public final class TooltipController: UIViewController {

    public var didShowConfig: ((TooltipConfig) -> ())?

    private var currentConfigIndex = 0

    private let tapGestureRecognizer = UITapGestureRecognizer()

    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    private let notificationFeedbackGenerator = UINotificationFeedbackGenerator()

    private let strongTransitioningDelegate = TooltipControllerTransitioningDelegate()

    private let arrowLayer = ArrowLayer()

    private let toolTipView = TooltipView(frame: .zero)

    private let configs: [TooltipConfig]

    public init(configs: [TooltipConfig]) {
        self.configs = configs

        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self.strongTransitioningDelegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.toolTipView)
        self.view.layer.addSublayer(self.arrowLayer)

        self.setUpSelf()
        self.setUpArrowLayer()
        self.setUpTooltipView()
        self.setUpTapGestureRecognizer()

        self.update(with: self.currentConfigIndex)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard self.view.frame != .zero else {
            return
        }

        self.locateTooltip()
    }

    private func setUpSelf() {
        self.view.backgroundColor = UIColor.res.clear.withAlphaComponent(0.02)
        self.view.addGestureRecognizer(self.tapGestureRecognizer)
    }

    private func setUpTapGestureRecognizer() {
        self.tapGestureRecognizer.addTarget(self, action: #selector(self.handleTap(recognizer:)))
    }

    private func setUpArrowLayer() {
        self.arrowLayer.update(direction: .top)
        self.arrowLayer.fillColor = UIColor.res.secondarySystemBackground.cgColor
    }

    private func setUpTooltipView() {
        self.toolTipView.isUserInteractionEnabled = false
        self.toolTipView.backgroundColor = UIColor.res.secondarySystemBackground
        self.toolTipView.layer.cornerRadius = 20
    }

    private func update(with configIndex: Int) {
        guard let currentConfig = self.configs[safeIndex: configIndex] else {
            return
        }

        self.currentConfigIndex = configIndex

        self.toolTipView.update(with: currentConfig)

        self.didShowConfig?(currentConfig)

        UIView.animate(withDuration: CATransaction.animationDuration()) {
            self.toolTipView.setNeedsLayout()
            self.toolTipView.layoutIfNeeded()

            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    private func locateTooltip() {
        guard let currentConfig = self.configs[safeIndex: self.currentConfigIndex] else {
            self.arrowLayer.frame = .zero
            self.toolTipView.frame = .zero

            return
        }

        let convertedSourceRect = self.view.convert(currentConfig.sourceRect, from: nil)

        let baseMargin: CGFloat = 12
        let hintViewMaxWidth: CGFloat = 300
        let totalViewWidth = self.view.bounds.width

        var baseStartPosition = convertedSourceRect.midX - hintViewMaxWidth / 2

        if baseStartPosition < baseMargin {
            baseStartPosition = baseMargin
        } else if baseStartPosition + hintViewMaxWidth > totalViewWidth - baseMargin {
            baseStartPosition = totalViewWidth - baseMargin - hintViewMaxWidth
        }

        let totalMargin = convertedSourceRect.maxY + ArrowLayer.offset + ArrowLayer.height
        
        self.toolTipView.pin
            .top(round(totalMargin))
            .start(round(baseStartPosition))
            .wrapContent(padding: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 12))

        self.arrowLayer.pin
            .start(convertedSourceRect.midX)
            .top(convertedSourceRect.maxY + ArrowLayer.offset * 1.5)
            .size(CGSize(width: ArrowLayer.width,
                         height: ArrowLayer.height))
    }

    @objc
    private func handleTap(recognizer: UITapGestureRecognizer) {
        let nextConfigIndex = self.currentConfigIndex + 1
        guard nextConfigIndex < self.configs.count else {
            self.notificationFeedbackGenerator.notificationOccurred(.success)
            self.dismiss(animated: true)

            return
        }

        self.impactFeedbackGenerator.impactOccurred()
        self.update(with: nextConfigIndex)
    }

}
