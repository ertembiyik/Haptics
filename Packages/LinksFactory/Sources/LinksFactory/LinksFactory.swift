import Foundation

public protocol LinksFactory {

    func linkForUser(with id: String) -> URL?

    @available(iOS 16, *)
    func notificationsSettings() -> URL

    func twitter() -> URL

    func telegramChangelog() -> URL

    func chatSupport() -> URL

    func privacyPolicy() -> URL

    func termsOfService() -> URL

    func ayo(with conversationId: String) -> URL

    func conversation(with conversationId: String) -> URL

    func main() -> URL

}
