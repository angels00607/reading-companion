import Foundation

/// Platform-independent WCAG contrast math used by the token audit and tests.
/// SwiftUI `Color` deliberately remains the rendering source of truth; these values
/// mirror the authoritative hex tokens so regressions are caught without screenshots.
public struct AccessibilityRGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(hex: UInt32) {
        red = Double((hex >> 16) & 255) / 255
        green = Double((hex >> 8) & 255) / 255
        blue = Double(hex & 255) / 255
    }

    public var relativeLuminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    public func contrastRatio(against other: AccessibilityRGB) -> Double {
        let values = [relativeLuminance, other.relativeLuminance]
        return (values.max()! + 0.05) / (values.min()! + 0.05)
    }
}

public struct SemanticContrastPair: Identifiable, Sendable {
    public let id: String
    public let foreground: AccessibilityRGB
    public let background: AccessibilityRGB
    public let minimumRatio: Double

    public init(_ id: String, foreground: UInt32, background: UInt32, minimumRatio: Double = 4.5) {
        self.id = id
        self.foreground = AccessibilityRGB(hex: foreground)
        self.background = AccessibilityRGB(hex: background)
        self.minimumRatio = minimumRatio
    }

    public var measuredRatio: Double { foreground.contrastRatio(against: background) }
    public var passes: Bool { measuredRatio >= minimumRatio }
}

public enum SemanticContrastAudit {
    public static let bodyTextPairs: [SemanticContrastPair] = [
        .init("Light text/background", foreground: 0x030B19, background: 0xF5EEF8),
        .init("Light text/surface", foreground: 0x030B19, background: 0xFFFFFF),
        .init("Light text/surface-blue", foreground: 0x030B19, background: 0xE7EAF6),
        .init("Light text/surface-plum", foreground: 0x030B19, background: 0xECD0EC),
        .init("Light secondary text/background", foreground: 0x4F6272, background: 0xF5EEF8),
        .init("Light secondary text/surface", foreground: 0x4F6272, background: 0xFFFFFF),
        .init("Light secondary text/surface-blue", foreground: 0x4F6272, background: 0xE7EAF6),
        .init("Light primary/background", foreground: 0x143D5B, background: 0xF5EEF8),
        .init("Light primary/surface", foreground: 0x143D5B, background: 0xFFFFFF),
        .init("Light primary/surface-blue", foreground: 0x143D5B, background: 0xE7EAF6),
        .init("Light on-plum/surface-plum", foreground: 0x7E2A53, background: 0xECD0EC),
        .init("Light on-primary/primary", foreground: 0xFFFFFF, background: 0x143D5B),
        .init("Light error/background", foreground: 0xA33A32, background: 0xF5EEF8),
        .init("Dark text/background", foreground: 0xF5F8FA, background: 0x030B19),
        .init("Dark text/surface", foreground: 0xF5F8FA, background: 0x151728),
        .init("Dark text/surface-blue", foreground: 0xF5F8FA, background: 0x242B49),
        .init("Dark text/surface-plum", foreground: 0xF5F8FA, background: 0x341F35),
        .init("Dark secondary text/background", foreground: 0xAFC3CF, background: 0x030B19),
        .init("Dark secondary text/surface", foreground: 0xAFC3CF, background: 0x151728),
        .init("Dark secondary text/surface-blue", foreground: 0xAFC3CF, background: 0x242B49),
        .init("Dark primary/background", foreground: 0xA9BCE3, background: 0x030B19),
        .init("Dark primary/surface", foreground: 0xA9BCE3, background: 0x151728),
        .init("Dark primary/surface-blue", foreground: 0xA9BCE3, background: 0x242B49),
        .init("Dark on-plum/surface-plum", foreground: 0xF5F8FA, background: 0x341F35),
        .init("Dark on-primary/primary", foreground: 0x030B19, background: 0xA9BCE3),
        .init("Dark error/background", foreground: 0xFFB4AB, background: 0x030B19)
    ]
}
