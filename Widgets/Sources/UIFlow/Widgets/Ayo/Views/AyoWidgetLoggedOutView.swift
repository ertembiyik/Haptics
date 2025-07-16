import SwiftUI
import Resources
import UIKitExtensions
import Dependencies
import LinksFactory

struct AyoWidgetLoggedOutView: View {

    @Dependency(\.linksFactory) private var linksFactory

    var body: some View {
        VStack(spacing: 4) {
            Text("🚪")
                .multilineTextAlignment(.center)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(String.res.ayoWidgetLoggedOutTitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(UIColor.res.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)

            Text(String.res.ayoWidgetLoggedOutSubtitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(UIColor.res.secondaryLabel.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)
                .padding(.horizontal, 12)

            AyoWidgetButton(backgroundGradientColors: [
                Color(red: 0, green: 62 / 255, blue: 185 / 255),
                Color(red: 0, green: 32 / 255, blue: 155 / 255)
            ],
                            foregroundGradientColors: [
                                Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255),
                                Color(red: 0, green: 92 / 255, blue: 215 / 255)
                            ],
                            text: String.res.ayoWidgetLoggedOutButtonTitle,
                            url: self.linksFactory.main(),
                            icon: nil
            )
            .padding([.horizontal, .bottom], 8)
            .padding(.top, 16)
        }
        .padding(.top, 20)
        .widgetBackground(UIColor.res.black.swiftUI)
    }

}

#Preview {
    AyoWidgetLoggedOutView()
}
