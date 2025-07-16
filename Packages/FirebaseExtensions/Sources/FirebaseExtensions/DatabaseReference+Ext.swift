import Combine
import FirebaseDatabase

public extension DatabaseReference {

    func toAnyPublisher(with type: DataEventType = .value) -> AnyPublisher<DataSnapshot, Never> {
        let subject = PassthroughSubject<DataSnapshot, Never>()

        let handle = observe(type, with: { snapshot in
            subject.send(snapshot)
        })

        return subject.handleEvents(receiveCancel: { [weak self] in
            self?.removeObserver(withHandle: handle)
        }).eraseToAnyPublisher()
    }

}
