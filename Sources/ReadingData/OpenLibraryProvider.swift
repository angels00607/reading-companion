import Foundation
import ReadingDomain
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ProviderError: Error { case invalidReference, unavailable, invalidResponse }
public actor OpenLibraryProvider: BooksCatalogProvider {
    public nonisolated let key = "openlibrary"
    private let session: URLSession
    private var lastRequest = Date.distantPast
    private var cache: [String: Data] = [:]
    public init(session: URLSession = .shared) { self.session = session }
    private func get(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        var parts = URLComponents(string: "https://openlibrary.org" + path)!
        parts.queryItems = query.isEmpty ? nil : query
        guard let url = parts.url else { throw ProviderError.invalidReference }
        if let data = cache[url.absoluteString] { return data }
        let wait = max(0, 1.1 - Date().timeIntervalSince(lastRequest))
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
        lastRequest = Date()
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
        request.setValue("ReadingCompanion/Phase2 (+https://github.com/angels00607/reading-companion)", forHTTPHeaderField: "User-Agent")
        let (data,response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count < 5_000_000 else { throw ProviderError.unavailable }
        cache[url.absoluteString] = data
        return data
    }
    private struct SearchResponse: Decodable { let docs: [SearchWork] }
    private struct SearchWork: Decodable { let key: String; let title: String?; let author_name: [String]?; let cover_i: Int? }
    public func searchWorks(query: String) async throws -> [WorkCandidate] {
        let data = try await get("/search.json", query: [.init(name: "q", value: query),.init(name: "lang", value: "en"),.init(name: "fields", value: "key,title,author_name,cover_i"),.init(name: "limit", value: "30")])
        return try JSONDecoder().decode(SearchResponse.self, from: data).docs.compactMap { row in
            let ref = row.key.hasPrefix("/works/") ? row.key : "/works/" + row.key
            guard valid(ref, prefix: "/works/", suffix: "W") else { return nil }
            return WorkCandidate(provider: key, reference: ref, title: row.title, author: row.author_name?.joined(separator: ", "), coverReference: row.cover_i.map { "https://covers.openlibrary.org/b/id/\($0)-M.jpg?default=false" })
        }
    }
    private struct EditionsResponse: Decodable { let entries: [ExternalEdition]; let size: Int? }
    private struct ExternalEdition: Decodable {
        let key: String; let title: String?; let languages: [Language]?; let number_of_pages: Int?
        let isbn_10: [String]?; let isbn_13: [String]?; let publishers: [String]?; let covers: [Int]?
        struct Language: Decodable { let key: String }
    }
    public func editions(for work: WorkCandidate) async throws -> [EditionCandidate] {
        guard work.provider == key, valid(work.reference, prefix: "/works/", suffix: "W") else { throw ProviderError.invalidReference }
        var found = [EditionCandidate]()
        // Bounded catalogue fetch. Missing/unfetched editions are never inferred.
        for offset in stride(from: 0, to: 200, by: 50) {
            let data = try await get(work.reference + "/editions.json", query: [.init(name: "limit", value: "50"),.init(name: "offset", value: String(offset))])
            let response = try JSONDecoder().decode(EditionsResponse.self, from: data)
            found += response.entries.compactMap { row in
                guard valid(row.key, prefix: "/books/", suffix: "M") else { return nil }
                let language = row.languages?.first?.key.split(separator: "/").last.map(String.init)
                let normalized = language == "eng" ? "en" : language == "fre" || language == "fra" ? "fr" : language
                return EditionCandidate(provider: key, reference: row.key, title: row.title, language: normalized,
                    isbn10: row.isbn_10?.first, isbn13: row.isbn_13?.first,
                    pageCount: row.number_of_pages.flatMap { $0 > 0 ? $0 : nil }, publisher: row.publishers?.joined(separator: ", "),
                    coverReference: row.covers?.first.flatMap { $0 > 0 ? "https://covers.openlibrary.org/b/id/\($0)-M.jpg?default=false" : nil })
            }
            if response.entries.count < 50 || offset + 50 >= (response.size ?? Int.max) { break }
        }
        return BooksRules.editionsEnglishFirst(found)
    }
    public func refresh(work: WorkCandidate) async throws -> WorkCandidate {
        guard work.provider == key, valid(work.reference, prefix: "/works/", suffix: "W") else { throw ProviderError.invalidReference }
        cache.removeValue(forKey: "https://openlibrary.org" + work.reference + ".json")
        let data = try await get(work.reference + ".json")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let object else { throw ProviderError.invalidResponse }
        var copy = work; copy.title = object["title"] as? String ?? work.title
        copy.synopsis = object["description"] as? String ?? (object["description"] as? [String: String])?["value"]
        if let cover = (object["covers"] as? [Int])?.first, cover > 0 { copy.coverReference = "https://covers.openlibrary.org/b/id/\(cover)-M.jpg?default=false" }
        return copy
    }
    private func valid(_ ref: String, prefix: String, suffix: String) -> Bool {
        ref.range(of: "^" + prefix + "OL[0-9]+" + suffix + "$", options: .regularExpression) != nil
    }
}

/// Deterministic QA data, injected only by DEBUG test launches, never returned by a live adapter.
public struct BooksAcceptanceProvider: BooksCatalogProvider {
    public let key = "qa-fixture"
    public init() {}
    public func searchWorks(query: String) async throws -> [WorkCandidate] {
        query.isEmpty ? [] : [WorkCandidate(provider: key, reference: "work-1", title: "The Long Way Home — Phase 2 QA Fixture", author: "A Very Long Author Name for Compact Layout QA", synopsis: "Clearly labelled test metadata, not a published book.")]
    }
    public func editions(for work: WorkCandidate) async throws -> [EditionCandidate] {
        [EditionCandidate(provider: key, reference: "edition-en", title: work.title, language: "en", pageCount: 400, publisher: "QA Fixture"),
         EditionCandidate(provider: key, reference: "edition-fr", title: "Fixture française — QA only", language: "fr", pageCount: 420)]
    }
    public func refresh(work: WorkCandidate) async throws -> WorkCandidate { work }
}
