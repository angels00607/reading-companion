import XCTest
import ReadingData
import ReadingDomain
import Foundation

private final class CatalogFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        if url.query?.contains("offline") == true { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        let json: String
        if url.path == "/search.json" {
            json = #"{"docs":[{"key":"/works/OL1W","title":"Fixture","author_name":["Author"],"cover_i":123}]}"#
        } else if url.path.hasSuffix("/editions.json") {
            json = #"{"size":2,"entries":[{"key":"/books/OL2M","title":"French fixture","languages":[{"key":"/languages/fre"}],"number_of_pages":420,"physical_format":"Hardcover"},{"key":"/books/OL1M","title":"English fixture","languages":[{"key":"/languages/eng"}],"number_of_pages":400,"isbn_13":["9780000000002"],"publishers":["Fixture"],"physical_format":"Audiobook"}]}"#
        } else { json = #"{"title":"Updated fixture","description":{"value":"External synopsis"}}"# }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ProviderTests: XCTestCase {
    func testProviderFailureLeavesOfflineLibraryUsable() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [CatalogFixtureProtocol.self]
        let provider = OpenLibraryProvider(session: URLSession(configuration: config))
        let store = try LocalStore(path: ":memory:", ownerID: UUID())
        let id = try store.add(work: WorkCandidate(provider: "manual", reference: "offline", title: "Offline book", author: "Author"))
        do { _ = try await provider.searchWorks(query: "offline"); XCTFail("Expected provider failure") } catch {}
        XCTAssertEqual(try store.library(query: "Offline").map(\.id),[id])
        let rid = try store.start(bookID: id, editionID: nil, date: nil)
        _ = try store.update(readingID: rid, value: .pages(current: 183), revision: 0)
        XCTAssertEqual(try store.record(id: id).active?.progress.currentPage,183)
    }
    func testRealAdapterWorkGroupingEditionLanguageAndFormatDiscard() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [CatalogFixtureProtocol.self]
        let provider = OpenLibraryProvider(session: URLSession(configuration: config))
        let works = try await provider.searchWorks(query: "fixture")
        XCTAssertEqual(works.count,1); XCTAssertEqual(works[0].reference,"/works/OL1W")
        let editions = try await provider.editions(for: works[0])
        XCTAssertEqual(editions.map(\.language),["en","fr"])
        let store = try LocalStore(path: ":memory:", ownerID: UUID())
        let id = try store.add(work: works[0], edition: editions[0])
        _ = try store.start(bookID: id, editionID: store.record(id: id).editions[0].id, date: nil)
        XCTAssertNil(try store.record(id: id).active?.journalFormat)
        let refreshed = try await provider.refresh(work: works[0])
        try store.reviewProvider(bookID: id, work: refreshed)
        XCTAssertEqual(try store.record(id: id).book.title,"Fixture")
        XCTAssertEqual(try store.proposals(bookID: id).count,2)
    }
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
