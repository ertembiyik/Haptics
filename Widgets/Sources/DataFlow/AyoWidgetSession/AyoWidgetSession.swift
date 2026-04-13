import Foundation

protocol AyoWidgetSession {

    func entry(for conversationId: String) async -> AyoWidgetEntry

}
