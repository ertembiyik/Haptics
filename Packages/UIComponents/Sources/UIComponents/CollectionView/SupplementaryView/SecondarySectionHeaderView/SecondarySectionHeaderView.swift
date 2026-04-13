import UIKit
import Combine
import PinLayout

public final class SecondarySectionHeaderView: BaseCollectionSupplementaryView {

    private static func attributedTitle(from text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 16
        paragraph.maximumLineHeight = 16
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold).rounded(),
            .foregroundColor: UIColor.res.secondaryLabel,
            .paragraphStyle: paragraph
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private let titleLabel = UILabel(frame: .zero)

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.titleLabel)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        self.titleLabel.pin
            .centerStart(24)
            .sizeToFit()
    }

    public override func apply(viewModel: SupplementaryViewModel) {
        guard let viewModel = viewModel as? SecondarySectionHeaderViewModel else {
            return
        }

        self.titleLabel.attributedText = Self.attributedTitle(from: viewModel.title.uppercased())
    }

}
