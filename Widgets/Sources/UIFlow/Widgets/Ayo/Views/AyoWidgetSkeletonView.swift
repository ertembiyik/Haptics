import SwiftUI
import Resources
import UIKitExtensions

struct AyoWidgetSkeletonView: View {

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(self.gradient)
                .frame(width: 56, height: 56)

            RoundedRectangle(cornerRadius: 6)
                .fill(self.gradient)
                .frame(width: 68, height: 22)

            RoundedRectangle(cornerRadius: 6)
                .fill(self.gradient)
                .padding([.horizontal, .bottom], 8)
                .padding(.top, 16)
        }
        .padding(.top, 16)
        .widgetBackground(UIColor.res.black.swiftUI)
    }

    private var gradient: some ShapeStyle {
        LinearGradient(
            colors: [UIColor.res.white.withAlphaComponent(0.12).swiftUI,
                     UIColor.res.white.withAlphaComponent(0.04).swiftUI],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    AyoWidgetSkeletonView()
}
