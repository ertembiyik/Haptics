import UIKit
import PinLayout

final class RedDotIndicator: UIView {

    private let colorView = UIView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.colorView)

        self.setUpSelf()
        self.setUpColorView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.colorView.pin
            .all()
    }

    private func setUpSelf() {
        self.isUserInteractionEnabled = false

        self.layer.masksToBounds = true
        self.layer.borderColor = UIColor.res.black.cgColor
        self.layer.borderWidth = 2
    }

    private func setUpColorView() {
        self.colorView.backgroundColor = UIColor.res.red
        self.colorView.clipsToBounds = true
    }

}
