import WidgetKit
import SwiftUI

extension WidgetConfiguration {

    func contentMarginsDisabledIfNeeded() -> some WidgetConfiguration {
#if compiler(>=5.9) // Xcode 15
        if #available(iOSApplicationExtension 15.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
#else
        return self
#endif
    }

}
