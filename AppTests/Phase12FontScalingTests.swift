import XCTest
import UIKit

final class Phase12FontScalingTests: XCTestCase {
    func testFunctionalFontsScaleThroughAccessibilityXXXL() throws {
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)

        for name in ["Manrope-Regular", "Manrope-Medium", "Manrope-SemiBold"] {
            let base = try XCTUnwrap(UIFont(name: name, size: 16), "Missing registered font \(name)")
            let metrics = UIFontMetrics(forTextStyle: .body)
            let standard = metrics.scaledFont(for: base, compatibleWith: standardTraits)
            let accessibility = metrics.scaledFont(for: base, compatibleWith: accessibilityTraits)
            XCTAssertGreaterThan(accessibility.pointSize, standard.pointSize, "\(name) must respond to Dynamic Type")
            XCTAssertEqual(standard.fontName, name)
            XCTAssertEqual(accessibility.fontName, name)
        }
    }
}
