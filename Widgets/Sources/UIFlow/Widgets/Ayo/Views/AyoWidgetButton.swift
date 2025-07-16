import SwiftUI
import Resources

struct AyoWidgetButton: View {

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let backgroundGradientColors: [Color]

    let foregroundGradientColors: [Color]

    let text: String

    let url: URL

    let icon: UIImage?

    var body: some View {
        Link(destination: self.url) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        LinearGradient(
                            colors: self.backgroundGradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .shadow(radius: 4, y: 4)

                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                UIColor.res.white.withAlphaComponent(0.22).swiftUI,
                                UIColor.res.white.withAlphaComponent(0).swiftUI,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(self.fillShape)
                    )

                HStack(spacing: 0) {
                    if let icon {
                        Image(uiImage: icon)
                            .foregroundStyle(UIColor.res.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)
                            .frame(width: 20, height: 20)
                    }

                    Text(self.text)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(UIColor.res.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).swiftUI)
                }
                .shadow(color: UIColor.res.black.withAlphaComponent(0.45).swiftUI, radius: 12, y: 1)
            }
        }
    }

    private var fillShape: some ShapeStyle {
        if self.widgetRenderingMode == .fullColor {
            AnyShapeStyle(LinearGradient(
                colors: self.foregroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            ))
        } else {
            AnyShapeStyle(Color.clear)
        }
    }

}

