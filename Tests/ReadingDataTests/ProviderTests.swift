import XCTest
import ReadingData
import ReadingDomain

final class ProviderTests: XCTestCase {
    func testEnglishPreferredWithoutInventingFrench() {
        let unknown = EditionCandidate(provider: "fixture", reference: "unknown")
        let en = EditionCandidate(provider: "fixture", reference: "en", language: "en")
        let sorted = BooksRules.editionsEnglishFirst([unknown,en])
        XCTAssertEqual(sorted.first?.language,"en")
        XCTAssertFalse(sorted.contains { $0.language == "fr" })
    }
    func testProviderContractCannotInferFormat() throws {
        let candidate = EditionCandidate(provider: "fixture", reference: "hardcover-edition", title: "Audiobook paperback", language: "en", isbn13: "9780000000002", pageCount: 400)
        let data = try JSONEncoder().encode(candidate)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("journalFormat"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("journal_format"))
    }
}
