import Combine
import FirebaseDatabase

extension DatabaseReference {

    func toAnyPublisher() -> AnyPublisher<DataSnapshot, Never> {
        let subject = PassthroughSubject<DataSnapshot, Never>()

        let handle = observe(.value, with: { snapshot in
            subject.send(snapshot)
        })

        return subject.handleEvents(receiveCancel: { [weak self] in
            self?.removeObserver(withHandle: handle)
        }).eraseToAnyPublisher()
    }

}
