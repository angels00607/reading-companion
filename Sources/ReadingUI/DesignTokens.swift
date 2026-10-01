import SwiftUI

public enum DesignTokens {
    public static let margin: CGFloat = 16
    public static let cardRadius: CGFloat = 14
    public static let buttonRadius: CGFloat = 12
    public static let minimumTouchTarget: CGFloat = 44
    public static func background(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x030B19 : 0xF8FAFB) }
    public static func surface(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x0D1B2A : 0xFFFFFF) }
    public static func text(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xF5F8FA : 0x030B19) }
    public static func secondaryText(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xAFC3CF : 0x4F6272) }
    public static func primary(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x91C9E2 : 0x143D5B) }
    public enum FunctionalFontWeight: String, Sendable {
        case regular = "Manrope-Regular", medium = "Manrope-Medium", semiBold = "Manrope-SemiBold"
    }
    public static func functionalFont(size: CGFloat, relativeTo style: Font.TextStyle = .body,
                                      weight: FunctionalFontWeight = .regular) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}
private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
