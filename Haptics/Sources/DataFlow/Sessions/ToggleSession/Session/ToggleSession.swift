import Foundation

protocol ToggleSession {

    func fetchAndSaveToggles(forced: Bool) async

    func toggle(named toggleName: ToggleName) -> Toggle?

}
