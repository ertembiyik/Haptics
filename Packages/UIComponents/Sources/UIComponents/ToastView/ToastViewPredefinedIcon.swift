import UIKit
import Resources

@available(iOS 15.0, *)
public enum ToastViewPredefinedIcon {

    case success
    case failure

    var icon: UIImage {
        switch self {
        case .success:
            let config = UIImage.SymbolConfiguration(hierarchicalColor: UIColor.res.green)
            return UIImage.res.checkmarkSquareFill.withConfiguration(config)
        case .failure:
            let config = UIImage.SymbolConfiguration(hierarchicalColor: UIColor.res.red)
            return UIImage.res.exclamationmarkTriangleFill.withConfiguration(config)
        }
    }
    
}
