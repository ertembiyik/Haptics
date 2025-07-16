import UIKit
import Combine
import UIComponents

final class SettingsCellViewModel: BaseCellViewModel {

    override static var reuseIdentifier: String {
        return "SettingsCell"
    }

    override var uid: String {
        self.id
    }

    private(set) var settingsData: SettingsCellData? {
        get {
            self.settingsDataSubject.value
        }

        set {
            self.settingsDataSubject.value = newValue
        }
    }

    let settingsDataPublisher: AnyPublisher<SettingsCellData?, Never>

    private let id: String

    private let onTap: () -> Void

    private let settingsDataSubject: CurrentValueSubject<SettingsCellData?, Never>

    private let syncQueue = DispatchQueue(label: "FriendsCellViewModel")

    init(id: String, 
         icon: UIImage,
         iconBackgroundColor: UIColor,
         title: String,
         trailingIcon: UIImage,
         roundedCorners: CACornerMask,
         trailingIconRotation: CGAffineTransform,
         onTap: @escaping () -> Void) {
        self.id = id
        self.onTap = onTap

        let baseData = SettingsCellData(icon: icon,
                                        iconBackgroundColor: iconBackgroundColor,
                                        title: title,
                                        trailingIcon: trailingIcon,
                                        roundedCorners: roundedCorners,
                                        trailingIconRotation: trailingIconRotation)
        let settingsDataSubject = CurrentValueSubject<SettingsCellData?, Never>(baseData)
        self.settingsDataSubject = settingsDataSubject
        self.settingsDataPublisher = settingsDataSubject.eraseToAnyPublisher()

        super.init()
    }

    func didTap() {
        self.onTap()
    }

    override func size(for collectionSize: CGSize) -> CGSize {
        return CGSize(width: collectionSize.width, height: 56)
    }

}
