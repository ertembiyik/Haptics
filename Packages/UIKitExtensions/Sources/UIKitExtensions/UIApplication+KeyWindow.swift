import UIKit

public extension UIApplication {

    var connectedKeyWindow: UIWindow? {
        return self.connectedScenes.compactMap { scene -> UIWindow? in
            guard let windowScene = scene as? UIWindowScene,
                  let keyWindow = windowScene.windows.first(where: \.isKeyWindow) else {
                return nil
            }

            return keyWindow
        }.first
    }
    
}

