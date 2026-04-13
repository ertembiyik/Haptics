import UIKit

@available(iOS 15.0, *)
public enum ToastViewEvent: Equatable {

    case hidden
    case icon(icon: UIImage, title: String, subtitle: String? = nil)
    case loading(title: String, subtitle: String? = nil)

    public static func icon(predefinedIcon: ToastViewPredefinedIcon, title: String, subtitle: String? = nil) -> ToastViewEvent {
        return .icon(icon: predefinedIcon.icon, title: title, subtitle: subtitle)
    }
    
}
