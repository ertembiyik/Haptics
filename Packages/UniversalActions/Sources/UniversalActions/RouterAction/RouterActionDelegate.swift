import Foundation

public protocol RouterActionDelegate: AnyObject {

    func route(to destination: RouteDestination)

}
