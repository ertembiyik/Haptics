import Dependencies

extension DependencyValues {

    private enum FeedbackSessionKey: DependencyKey {
        static let liveValue: FeedbackSession = FeedbackSessionImpl()
    }

    var feedbackSession: FeedbackSession {
        get {
            self[FeedbackSessionKey.self]
        }

        set {
            self[FeedbackSessionKey.self] = newValue
        }
    }

}
