import UIKit
import Combine
import PinLayout
import UIComponents

final class FriendsSupplementaryInfoView: BaseCollectionSupplementaryView {

    private let emojiInfoView = EmojiInfoView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.emojiInfoView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.emojiInfoView.pin
            .all()
    }

    override func apply(viewModel: any SupplementaryViewModel) {
        guard let viewModel = viewModel as? FriendsSupplementaryInfoViewModel else {
            return
        }

        self.emojiInfoView.emoji = viewModel.emoji
        self.emojiInfoView.title = viewModel.title
        self.emojiInfoView.subtitle = viewModel.subtitle
        self.setNeedsLayout()
    }

}
