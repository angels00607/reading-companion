import SwiftUI

public enum DesignTokens {
    public enum Spacing {
        public static let xSmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xLarge: CGFloat = 24
        public static let xxLarge: CGFloat = 32
    }
    public static let margin: CGFloat = 16
    public static let cardRadius: CGFloat = 14
    public static let buttonRadius: CGFloat = 12
    public static let inputRadius: CGFloat = 10
    public static let coverRadius: CGFloat = 8
    public static let progressRadius: CGFloat = 7
    public static let sheetRadius: CGFloat = 22
    public static let minimumTouchTarget: CGFloat = 44
    public static func background(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x030B19 : 0xF5EEF8) }
    public static func surface(_ scheme: ColorScheme) -> Color {
        let candidateDarkSurface = ProcessInfo.processInfo.arguments.contains("-phase1-dark-surface-candidate")
        return Color(hex: scheme == .dark ? (candidateDarkSurface ? 0x151728 : 0x0D1B2A) : 0xFFFFFF)
    }
    public static func raisedSurface(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x13283A : 0xFFFFFF) }
    public static func blueSurface(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x242B49 : 0xE7EAF6) }
    public static func plumSurface(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x341F35 : 0xECD0EC) }
    public static func text(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xF5F8FA : 0x030B19) }
    public static func secondaryText(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xAFC3CF : 0x4F6272) }
    public static func primary(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xA9BCE3 : 0x143D5B) }
    public static func primarySoft(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xA9BCE3 : 0x9EB7D8) }
    public static func onPrimary(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x030B19 : 0xFFFFFF) }
    public static func primaryStrong(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x4F81AA : 0x143D5B) }
    public static func secondary(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xBA71A2 : 0x7E2A53) }
    public static func border(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x24445B : 0xDCE6EA) }
    public static func error(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xFFB4AB : 0xA33A32) }
    public enum FunctionalFontWeight: String, Sendable {
        case regular = "Manrope-Regular", medium = "Manrope-Medium", semiBold = "Manrope-SemiBold"
    }
    public static func functionalFont(size: CGFloat, relativeTo style: Font.TextStyle = .body,
                                      weight: FunctionalFontWeight = .regular) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
    public static func journalAccent(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("PapernotesRegular", size: size, relativeTo: style)
    }
    public static func celebrationAccent(size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("HelloBabyRegular", size: size, relativeTo: style)
    }
}
public extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
