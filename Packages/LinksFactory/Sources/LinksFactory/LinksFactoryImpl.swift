import UIKit

public final class LinksFactoryImpl: LinksFactory {

    public func linkForUser(with id: String) -> URL? {
        let absoluteUrl = "https://thehaptics.app/users/\(id)"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)
        } else {
            return URL(string: absoluteUrl)
        }
    }

    @available(iOS 16, *)
    public func notificationsSettings() -> URL {
        let absoluteUrl = UIApplication.openNotificationSettingsURLString

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }

    public func twitter() -> URL {
        let absoluteUrl = "https://x.com/hapticshq"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }

    public func telegramChangelog() -> URL {
        let absoluteUrl = "https://t.me/hapticsapp"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }

    public func chatSupport() -> URL {
        let absoluteUrl = "https://t.me/hapticsapp_bot"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }

    public func privacyPolicy() -> URL {
        let absoluteUrl = "https://thehaptics.app/legal/privacy"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }

    public func termsOfService() -> URL {
        let absoluteUrl = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }

    public func ayo(with conversationId: String) -> URL {
        let absoluteUrl = "haptics://ayo-small/ayo/\(conversationId)"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }

    public func conversation(with conversationId: String) -> URL {
        let absoluteUrl = "haptics://ayo-small/conversation/\(conversationId)"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }

    public func main() -> URL {
        let absoluteUrl = "https://thehaptics.app"

        if #available(iOS 17.0, *) {
            return URL(string: absoluteUrl, encodingInvalidCharacters: false)!
        } else {
            return URL(string: absoluteUrl)!
        }
    }
}
