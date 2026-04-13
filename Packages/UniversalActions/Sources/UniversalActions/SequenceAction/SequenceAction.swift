import Foundation
import Dependencies

public struct SequenceAction: UniversalAction {

    private let actions: [any UniversalAction]

    public init(actions: [any UniversalAction]) {
        self.actions = actions
    }

    public func perform() async throws {
        for action in actions {
            try await action.perform()
        }
    }

}
