import XCTest
import UIKit

final class Phase12FontScalingTests: XCTestCase {
    func testFunctionalFontsScaleThroughAccessibilityXXXL() throws {
        try assertFontsScale([
            ("Manrope-Regular", 16, .body),
            ("Manrope-Medium", 16, .body),
            ("Manrope-SemiBold", 16, .body)
        ])
    }

    func testExpressiveFontsScaleThroughAccessibilityXXXL() throws {
        try assertFontsScale([
            ("PapernotesRegular", 20, .title3),
            ("HelloBabyRegular", 32, .title1)
        ])
    }

    private func assertFontsScale(_ fonts: [(String, CGFloat, UIFont.TextStyle)],
                                  file: StaticString = #filePath,
                                  line: UInt = #line) throws {
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)

        for (name, size, style) in fonts {
            let base = try XCTUnwrap(UIFont(name: name, size: size), "Missing registered font \(name)", file: file, line: line)
            let metrics = UIFontMetrics(forTextStyle: style)
            let standard = metrics.scaledFont(for: base, compatibleWith: standardTraits)
            let accessibility = metrics.scaledFont(for: base, compatibleWith: accessibilityTraits)
            XCTAssertGreaterThan(accessibility.pointSize, standard.pointSize,
                                 "\(name) must respond to Dynamic Type", file: file, line: line)
            XCTAssertEqual(standard.fontName, name, file: file, line: line)
            XCTAssertEqual(accessibility.fontName, name, file: file, line: line)
        }
    }
}
