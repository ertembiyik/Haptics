import Foundation

final class StateMachine<State, Event> {

    typealias StateEventMapper = (State, Event) -> State?
    typealias OnStateTransition = (State, Event) -> Void
    typealias SameEventResolver = (Event, Event) -> Bool

    private var stateEventMapper: StateEventMapper
    private var sameEventResolver: SameEventResolver?
    var onStateTransition: OnStateTransition?

    private var currentState: State
    private var previousEvent: Event?

    init(initialState: State,
         stateEventMapper: @escaping StateEventMapper,
         sameEventResolver: SameEventResolver? = nil) {
        self.stateEventMapper = stateEventMapper
        self.sameEventResolver = sameEventResolver
        self.currentState = initialState
    }

    func send(_ event: Event) {
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
