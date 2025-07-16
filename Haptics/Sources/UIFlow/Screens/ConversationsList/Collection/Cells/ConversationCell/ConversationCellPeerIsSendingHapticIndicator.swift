import UIKit
import PinLayout

final class ConversationCellPeerIsSendingHapticIndicator: UIView {

    private let imageView = UIImageView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.imageView)
        self.setUpSelf()
        self.setUpImageView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.imageView.pin
            .center()
            .size(CGSize(width: 11, height: 11))
    }

    private func setUpSelf() {
        self.isUserInteractionEnabled = false
        self.backgroundColor = UIColor.res.systemGreen
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        
        self.layer.masksToBounds = true
        self.layer.borderColor = UIColor.res.black.cgColor
        self.layer.borderWidth = 2
    }

    private func setUpImageView() {
        let image = UIImage.res.handWaveFill
            .withTintColor(UIColor.res.white, renderingMode: .alwaysOriginal)
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 11))

        self.imageView.contentMode = .scaleAspectFit
        self.imageView.clipsToBounds = true
        self.imageView.image = image
    }

}
