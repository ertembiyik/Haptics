import Foundation

public struct LoaderFooterErrorData {

    public let hasError: Bool

    public let fallback: (() async throws -> Void)?

    public init(hasError: Bool, fallback: (() async throws -> Void)?) {
        self.hasError = hasError
        self.fallback = fallback
    }

}
