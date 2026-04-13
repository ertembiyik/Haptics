import Foundation
import Dependencies

public struct RouterAction: UniversalAction {

    @Dependency(\.universalActionContext) private var context

    private let routeDestination: RouteDestination

    public init(routeDestination: RouteDestination) {
        self.routeDestination = routeDestination
    }

    public func perform() async throws {
        self.context.routerDelegate?.route(to: self.routeDestination)
    }

}
