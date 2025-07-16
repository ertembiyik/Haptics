import Foundation

public final class StateMachine<State, Event> {

    public typealias StateEventMapper = (State, Event) -> State?
    public typealias OnStateTransition = (State, Event) -> Void
    public typealias SameEventResolver = (Event, Event) -> Bool

    public var onStateTransition: OnStateTransition?
    public private(set) var currentState: State

    private var stateEventMapper: StateEventMapper
    private var sameEventResolver: SameEventResolver?

    private var previousEvent: Event?

    public init(initialState: State,
                stateEventMapper: @escaping StateEventMapper,
                sameEventResolver: SameEventResolver? = nil) {
        self.stateEventMapper = stateEventMapper
        self.sameEventResolver = sameEventResolver
        self.currentState = initialState
    }

    public func send(_ event: Event) {
        if let sameEventResolver, let previousEvent, !sameEventResolver(previousEvent, event) {
            return
        }

        self.previousEvent = event

        if let nextState = self.stateEventMapper(self.currentState, event) {
            if let onStateTransition {
                onStateTransition(self.currentState, event)
            }

            self.currentState = nextState
        }
    }
}
