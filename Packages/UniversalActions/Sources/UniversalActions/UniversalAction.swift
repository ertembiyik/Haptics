import Foundation

public protocol UniversalAction {

    var toastConfig: UniversalActionToastConfig? { get }

    func perform() async throws
    
}

public extension UniversalAction {

    var toastConfig: UniversalActionToastConfig? {
        return nil
    }

}
