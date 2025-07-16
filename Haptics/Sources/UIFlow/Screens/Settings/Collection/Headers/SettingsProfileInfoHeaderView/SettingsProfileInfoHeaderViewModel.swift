import Foundation
import Dependencies
import Combine
import UIComponents

final class SettingsProfileInfoHeaderViewModel: BaseSupplementaryViewModel {

    static override var reuseIdentifier: String {
        return "SettingsProfileInfoHeaderView"
    }

    private(set) var profileHeaderData: SettingsProfileInfoHeaderData? {
        get {
            self.profileHeaderDataSubject.value
        }

        set {
            self.profileHeaderDataSubject.value = newValue
        }
    }

    let profileHeaderDataPublisher: AnyPublisher<SettingsProfileInfoHeaderData?, Never>

    private let profileHeaderDataSubject: CurrentValueSubject<SettingsProfileInfoHeaderData?, Never>

    private let syncQueue = DispatchQueue(label: "SettingsProfileInfoHeaderViewModel")

    @Dependency(\.authSession) private var authSession

    @Dependency(\.profileSession) private var profileSession

    @Dependency(\.storeSession) private var storeSession

    override init() {
        let profileHeaderDataSubject = CurrentValueSubject<SettingsProfileInfoHeaderData?, Never>(nil)
        self.profileHeaderDataSubject = profileHeaderDataSubject
        self.profileHeaderDataPublisher = profileHeaderDataSubject.eraseToAnyPublisher()

        super.init()

        self.register(cancellable: self.storeSession.isProPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPro in
                self?.didReceive(isPro: isPro)
            })

        self.didReceive(isPro: self.storeSession.isPro)
    }

    func loadData() async throws {
        guard let userId = self.authSession.state.userId else {
            throw SettingsProfileInfoHeaderViewModelError.invalidAuthState
        }

        let profile = try await self.profileSession.getProfile(for: userId)

        self.syncQueue.async {
            self.profileHeaderData = SettingsProfileInfoHeaderData(profile: profile, isPro: self.storeSession.isPro)
        }
    }

    private func didReceive(isPro: Bool) {
        guard let profileHeaderData else {
            return
        }

        self.syncQueue.async {
            self.profileHeaderData = SettingsProfileInfoHeaderData(profile: profileHeaderData.profile, isPro: isPro)
        }
    }

    override func size(for collectionSize: CGSize) -> CGSize {
        return CGSize(width: collectionSize.width, height: 229)
    }

}
