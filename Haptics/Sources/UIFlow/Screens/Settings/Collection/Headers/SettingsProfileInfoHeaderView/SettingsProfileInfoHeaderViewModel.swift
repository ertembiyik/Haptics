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

    override init() {
        let profileHeaderDataSubject = CurrentValueSubject<SettingsProfileInfoHeaderData?, Never>(nil)
        self.profileHeaderDataSubject = profileHeaderDataSubject
        self.profileHeaderDataPublisher = profileHeaderDataSubject.eraseToAnyPublisher()

        super.init()
    }

    func loadData() async throws {
        guard let userId = self.authSession.state.userId else {
            throw SettingsProfileInfoHeaderViewModelError.invalidAuthState
        }

        let profile = try await self.profileSession.getProfile(for: userId)

        self.syncQueue.async {
            self.profileHeaderData = SettingsProfileInfoHeaderData(profile: profile, isPro: false)
        }
    }

    override func size(for collectionSize: CGSize) -> CGSize {
        return CGSize(width: collectionSize.width, height: 229)
    }

}
