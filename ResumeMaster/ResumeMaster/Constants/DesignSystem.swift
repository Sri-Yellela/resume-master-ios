import SwiftUI
import UIKit

enum DS {
    enum ColorToken {
        static let background = Color.adaptive(light: 0xF7F6F2, dark: 0x171614)
        static let surface = Color.adaptive(light: 0xF9F8F5, dark: 0x1C1B19)
        static let surfaceOffset = Color.adaptive(light: 0xF3F0EC, dark: 0x1D1C1A)
        static let text = Color.adaptive(light: 0x28251D, dark: 0xCDCCCA)
        static let textMuted = Color.adaptive(light: 0x7A7974, dark: 0x797876)
        static let textFaint = Color.adaptive(light: 0xBAB9B4, dark: 0x5A5957)
        static let primary = Color.adaptive(light: 0x01696F, dark: 0x4F98A3)
        static let border = Color.adaptive(light: 0xD4D1CA, dark: 0x393836)
        static let success = Color.adaptive(light: 0x437A22, dark: 0x6DAA45)
        static let warning = Color.adaptive(light: 0x964219, dark: 0xBB653B)
        static let error = Color.adaptive(light: 0xA12C7B, dark: 0xD163A7)
        static let gold = Color(red: 0.86, green: 0.61, blue: 0.18)
    }
    enum FontToken { static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }; static let body = Font.system(size: 16); static let label = Font.system(size: 13, weight: .medium); static let caption = Font.system(size: 11) }
    enum Spacing { static let xs: CGFloat = 4; static let sm: CGFloat = 8; static let md: CGFloat = 16; static let lg: CGFloat = 24; static let xl: CGFloat = 32; static let xxl: CGFloat = 48 }
    enum Radius { static let sm: CGFloat = 6; static let md: CGFloat = 10; static let lg: CGFloat = 16; static let xl: CGFloat = 24; static let full: CGFloat = 999 }
}
extension Color { static func adaptive(light: UInt32, dark: UInt32) -> Color { Color(UIColor { UIColor(hex: $0.userInterfaceStyle == .dark ? dark : light) }) }; init(hex: String) { self = Color(UIColor(hex: UInt32(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x01696F)) } }
extension UIColor { convenience init(hex: UInt32) { self.init(red: CGFloat((hex>>16)&255)/255, green: CGFloat((hex>>8)&255)/255, blue: CGFloat(hex&255)/255, alpha: 1) } }
