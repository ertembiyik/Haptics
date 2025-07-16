import UIKit

extension UIColor {
    
    private static func normalizedHexCode(_ hexColor: String) -> String {
        var hex = hexColor.hasPrefix("#") ? String(hexColor.dropFirst()) : hexColor
        if hex.count == 3 || hex.count == 4 {
            hex = hex.map { "\($0)\($0)" } .joined()
        }

        return hex
    }

    static func color(with hex: String) -> UIColor? {
        let hexCode = Self.normalizedHexCode(hex)
        guard !hexCode.isEmpty, let hexInt = UInt32(hexCode, radix: 16) else {
            return nil
        }

        switch hexCode.count {
        case 6:
            return UIColor(red: CGFloat(hexInt >> 16 & 0xFF) / 255,
                           green: CGFloat(hexInt >> 8 & 0xFF) / 255,
                           blue: CGFloat(hexInt & 0xFF) / 255,
                           alpha: 1)
        case 8:
            let rgbHex = hexInt >> 8
            return UIColor(red: CGFloat(rgbHex >> 16 & 0xFF) / 255,
                           green: CGFloat(rgbHex >> 8 & 0xFF) / 255,
                           blue: CGFloat(rgbHex & 0xFF) / 255,
                           alpha: CGFloat(hexInt & 0xFF) / 255)
        default:
            return nil
        }
    }

    var hex: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let components = UInt8(round(alpha * 255)) != 255 ? [red, green, blue, alpha] : [red, green, blue]

        return "#" + components.map { String(format: "%02X", UInt8(round($0 * 255))) }.joined()
    }

}
