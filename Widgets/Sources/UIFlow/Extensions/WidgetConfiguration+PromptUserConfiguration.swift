import SwiftUI

extension WidgetConfiguration {

    func promptsForUserConfigurationIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 18.0, *) {
            return self.promptsForUserConfiguration()
        } else {
            return self
        }
    }

}
