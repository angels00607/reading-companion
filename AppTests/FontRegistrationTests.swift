import XCTest
import UIKit

final class FontRegistrationTests: XCTestCase {
    @MainActor
    func testEveryApprovedFontIsBundledAndRegisteredWithoutFallback() throws {
        let expected = [
            "Manrope-Regular.ttf": "Manrope-Regular",
            "Manrope-Medium.ttf": "Manrope-Medium",
            "Manrope-SemiBold.ttf": "Manrope-SemiBold",
            "PapernotesRegular.otf": "PapernotesRegular",
            "Hello Baby.otf": "HelloBabyRegular"
        ]
        let declared = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        XCTAssertEqual(Set(declared), Set(expected.keys))
        for (file, postScriptName) in expected {
            XCTAssertNotNil(Bundle.main.url(forResource: file, withExtension: nil), file)
            let font = try XCTUnwrap(UIFont(name: postScriptName, size: 16), postScriptName)
            XCTAssertEqual(font.fontName, postScriptName)
            print("REGISTERED FONT: \(file) -> \(font.fontName); family=\(font.familyName)")
        }
    }
}
