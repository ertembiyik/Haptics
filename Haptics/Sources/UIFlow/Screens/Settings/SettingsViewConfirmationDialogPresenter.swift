import Foundation

@MainActor
protocol SettingsViewConfirmationDialogPresenter: AnyObject {

    func confirmDeleteAccount(with handler: @escaping () -> Void)

    func confirmSignOut(with handler: @escaping () -> Void)

}
