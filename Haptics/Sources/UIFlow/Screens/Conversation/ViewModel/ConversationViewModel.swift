import UIKit
import Combine
import Dependencies
import FirebaseDatabase
import OSLog
import RemoteDataModels
import HapticsConfiguration

final class ConversationViewModel {

    let hapticPublisher: AnyPublisher<RemoteDataModels.Haptic, Never>

    private var hapticCancellable: AnyCancellable?

    private var isStarted = false

    private var cancellabels = Set<AnyCancellable>()

    private let hapticSubject: PassthroughSubject<RemoteDataModels.Haptic, Never>

    private let syncQueue = DispatchQueue(label: "ConversationViewModel")

    @Dependency(\.authSession) private var authSession

    @Dependency(\.conversationsSession) private var conversationsSession

    @Dependency(\.configuration.realtimeDatabaseUrl) private var realtimeDatabaseUrl

    init() {
        let hapticSubject = PassthroughSubject<RemoteDataModels.Haptic, Never>()

        self.hapticSubject = hapticSubject
        self.hapticPublisher = hapticSubject.eraseToAnyPublisher()
    }

    func onStart() {
        guard !self.isStarted else {
            return
        }

        self.isStarted = true

        self.conversationsSession.selectedConversationIdPublisher
            .dropFirst()
            .receive(on: self.syncQueue)
            .sink { [weak self] selectedConversationId in
                guard let selectedConversationId else {
                    return
                }

                self?.connect(with: selectedConversationId)
            }
            .store(in: &self.cancellabels)

        if let selectedConversationId = self.conversationsSession.selectedConversationId {
            self.connect(with: selectedConversationId)
        }
    }

    func sendHaptic(from rect: CGRect, at location: CGPoint) async throws {
        guard let senderId = self.authSession.state.userId else {
            throw ConversationViewModelError.invalidAuthState
        }

        guard let selectedConversationId = self.conversationsSession.selectedConversationId else {
            throw ConversationViewModelError.conversationWasNotSelected
        }

        let haptic = RemoteDataModels.Haptic(senderId: senderId, type: .default(.init(fromRect: rect, location: location)))

        try await self.conversationsSession.send(haptic: haptic, to: selectedConversationId)
    }

    func send(emoji: String, from rect: CGRect, at location: CGPoint) async throws {
        guard let senderId = self.authSession.state.userId else {
            throw ConversationViewModelError.invalidAuthState
        }

        guard let selectedConversationId = self.conversationsSession.selectedConversationId else {
            throw ConversationViewModelError.conversationWasNotSelected
        }

        let haptic = RemoteDataModels.Haptic(senderId: senderId,
                                             type: .emoji(.init(fromRect: rect, location: location, emoji: emoji)))

        try await self.conversationsSession.send(haptic: haptic, to: selectedConversationId)
    }

    func sendSketch(with locations: [CGPoint],
                    from rect: CGRect,
                    color: UIColor,
                    lineWidth: CGFloat,
                    id: String) async throws {
        guard let senderId = self.authSession.state.userId else {
            throw ConversationViewModelError.invalidAuthState
        }

        guard let selectedConversationId = self.conversationsSession.selectedConversationId else {
            throw ConversationViewModelError.conversationWasNotSelected
        }

        let haptic = RemoteDataModels.Haptic(senderId: senderId,
                                             id: id,
                                             type: .sketch(.init(fromRect: rect, locations: locations, color: color, lineWidth: lineWidth)))

        try await self.conversationsSession.send(haptic: haptic, to: selectedConversationId)
    }

    func connect(with conversationId: String) {
        if let hapticCancellable {
            hapticCancellable.cancel()
        }

        self.hapticCancellable = self.conversationsSession.conversationsPublisher
            .receive(on: self.syncQueue)
            .compactMap { conversations in
                conversations[conversationId]
            }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] haptic in
                self?.didReceive(haptic: haptic)
            }
    }

    private func didReceive(haptic: RemoteDataModels.Haptic) {
        self.hapticSubject.send(haptic)
    }

}
