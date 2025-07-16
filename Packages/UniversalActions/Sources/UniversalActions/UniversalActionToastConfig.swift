import Foundation

public struct UniversalActionToastConfig {

    public let loadingTitle: String

    public let loadingSubtitle: String?

    public let errorTitle: ((Error) -> String)?

    public let errorDescription: ((Error) -> String)?

    public let successTitle: String?

    public let successDescription: String?

    public init(loadingTitle: String,
                loadingSubtitle: String? = nil,
                errorTitle: ((Error) -> String)? = nil,
                errorDescription: ((Error) -> String)? = nil,
                successTitle: String? = nil,
                successDescription: String? = nil) {
        self.loadingTitle = loadingTitle
        self.loadingSubtitle = loadingSubtitle
        self.errorTitle = errorTitle
        self.errorDescription = errorDescription
        self.successTitle = successTitle
        self.successDescription = successDescription
    }

}
