import Foundation

public protocol TooltipsSession {

    func shouldShowTooltip(with tooltipId: String, userId: String) -> Bool

    func markTooltipAsShown(with tooltipId: String, userId: String)

    func registerTooltips(with tooltipIds: [String], userId: String)

    func resetTooltips(with tooltipIds: [String], for userId: String)

    func resetAllTooltips(for userId: String)

}
