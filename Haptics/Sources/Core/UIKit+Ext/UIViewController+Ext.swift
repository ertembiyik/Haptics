import UIKit

extension UIViewController {

    var isPresentedModally: Bool {
        let presentingIsModal = self.presentingViewController != nil
        let presentingIsNavigation = self.navigationController?.presentingViewController?.presentedViewController == self.navigationController
        let presentingIsTabBar = self.tabBarController?.presentingViewController is UITabBarController

        return presentingIsModal || presentingIsNavigation || presentingIsTabBar
    }
    
}
