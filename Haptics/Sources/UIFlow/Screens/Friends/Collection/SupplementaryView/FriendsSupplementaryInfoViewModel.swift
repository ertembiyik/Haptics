import Foundation
import UIComponents

final class FriendsSupplementaryInfoViewModel: SupplementaryViewModel {

    let emoji: String

    let title: String

    let subtitle: String

    private let sizeResolver: (CGSize) -> CGSize

    init(emoji: String,
         title: String,
         subtitle: String,
         sizeResolver: @escaping (CGSize) -> CGSize) {
        self.emoji = emoji
        self.title = title
        self.subtitle = subtitle

        self.sizeResolver = sizeResolver
    }

    static var reuseIdentifier: String {
        return "FriendsSupplementaryInfoView"
    }

    func size(for collectionSize: CGSize) -> CGSize {
        return self.sizeResolver(collectionSize)
    }

}
