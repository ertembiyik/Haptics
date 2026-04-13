import Foundation

@MainActor
protocol FriendsViewConfirmationDialogPresenter: AnyObject {

    func confirmRemoveConversation(with handler: @escaping () -> Void)

}
