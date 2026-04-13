import SwiftUI
import Resources
import UIKitExtensions

struct AyoWidgetSelectedView: View {

    let emoji: String

    let name: String

    let conversationUrl: URL

    let ayoUrl: URL

    var body: some View {
        VStack(spacing: 4) {
            Link(destination: self.conversationUrl) {
                Text(self.emoji)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .frame(width: 56, height: 56)
                    .background(UIColor.res.quaternarySystemFill.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)
                    .clipShape(Circle())

                Text(self.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(UIColor.res.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)
            }

            AyoWidgetButton(backgroundGradientColors: [
                Color(red: 205 / 255, green: 5 / 255, blue: 45 / 255),
                Color(red: 125 / 255, green: 0 / 255, blue: 0 / 255)
            ],
                            foregroundGradientColors: [
                                Color(red: 255 / 255, green: 55 / 255, blue: 95 / 255),
                                Color(red: 185 / 255, green: 0 / 255, blue: 25 / 255)
                            ],
                            text: String.res.ayoWidgetSelectedButtonTitle,
                            url: self.ayoUrl,
                            icon: UIImage.res.emojiPeaceHandSignFill
                .withRenderingMode(.alwaysTemplate)
                .withTintColor(UIColor.res.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
            )
            .padding([.horizontal, .bottom], 8)
            .padding(.top, 16)
        }
        .padding(.top, 16)
        .widgetBackground(UIColor.res.black.swiftUI)
    }

}
