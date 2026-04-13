import SwiftUI
import Resources
import UIKitExtensions

struct AyoWidgetPlaceHolderView: View {

    let emoji: String

    let title: String

    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(self.emoji)
                .multilineTextAlignment(.center)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(self.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(UIColor.res.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)

            Text(self.subtitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(UIColor.res.secondaryLabel.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)
        }
        .padding(.horizontal, 12)
        .widgetBackground(UIColor.res.black.swiftUI)
    }

}

