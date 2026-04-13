import Foundation

public struct LoaderFooterStateData {

    public let isLoading: Bool

    public let hasError: Bool

    public let refreshAction: (() async throws -> Void)?

    public init(isLoading: Bool, hasError: Bool, refreshAction: (() async throws -> Void)?) {
        self.isLoading = isLoading
        self.hasError = hasError
        self.refreshAction = refreshAction
    }
}
