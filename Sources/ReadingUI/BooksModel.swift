import Foundation
import SwiftUI
import ReadingDomain

@MainActor
public final class BooksModel: ObservableObject {
    public let repository: any BooksRepository
    public let provider: any BooksCatalogProvider
    public let assetDirectory: URL
    @Published public var version = 0
    @Published public var error: String?
    @Published public var feedback: String?
    @Published public var feedbackReadingID: UUID?
    public init(repository: any BooksRepository, provider: any BooksCatalogProvider, assetDirectory: URL) {
        self.repository = repository; self.provider = provider; self.assetDirectory = assetDirectory
    }
    @discardableResult public func perform<T>(_ body: () throws -> T) -> T? {
        do { let value = try body(); error = nil; version += 1; return value }
        catch DomainError.staleRevision { error = "The record changed. Reload and review before applying this change." }
        catch DomainError.invalidProgress { error = "Enter a valid position: pages must be whole numbers within the known total; percentage must be between 0 and 100." }
        catch BooksError.activeReadingExists { error = "This book already has an active reading. Open it to update progress." }
        catch BooksError.requiredMetadata { error = "Enter a title and author. Optional metadata may stay unknown." }
        catch BooksError.invalidMetadata { error = "Check the supplied information. Cover references must be a chosen photo or a valid HTTPS URL." }
        catch DomainError.invalidDate { error = "Use a valid date in YYYY-MM-DD format, or leave it blank for unknown." }
        catch { self.error = "Could not save this change. Existing local data has not changed. \(error.localizedDescription)" }
        return nil
    }
    public func coverURL(_ reference: String?) -> URL? {
        guard let reference else { return nil }
        if reference.hasPrefix("asset://"), let id = UUID(uuidString: String(reference.dropFirst(8)).replacingOccurrences(of: ".png", with: "")) {
            return assetDirectory.appendingPathComponent(id.uuidString + ".png")
        }
        guard let url = URL(string: reference), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    public func saveCover(_ data: Data) throws -> String {
        guard data.count <= 10_000_000 else { throw BooksError.invalidMetadata }
        try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
        let id = UUID(); try data.write(to: assetDirectory.appendingPathComponent(id.uuidString + ".png"), options: .atomic)
        return "asset://" + id.uuidString + ".png"
    }
    public static var today: ReadingDate {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year,.month,.day], from: Date())
        return try! ReadingDate(year: parts.year!, month: parts.month!, day: parts.day!)
    }
    public static func parseDate(_ value: String) throws -> ReadingDate? {
        if value.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        return try JSONDecoder().decode(ReadingDate.self, from: JSONEncoder().encode(value))
    }
    public static func optionalPages(_ value: String) throws -> Int? {
        if value.isEmpty { return nil }
        guard let pages = Int(value), pages > 0 else { throw DomainError.invalidProgress }; return pages
    }
}

struct BooksScreen<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .frame(maxWidth: .infinity, alignment: .leading).padding(DesignTokens.margin).padding(.bottom, 24)
        }.background(DesignTokens.background(scheme)).foregroundStyle(DesignTokens.text(scheme))
            .font(DesignTokens.functionalFont(size: 16)).navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            #endif
    }
}
struct BooksField: View {
    let label: String
    @Binding var value: String
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(DesignTokens.functionalFont(size: 14, weight: .medium))
            TextField(label, text: $value, axis: .vertical).textFieldStyle(.roundedBorder)
                .font(DesignTokens.functionalFont(size: 16)).frame(minHeight: 44)
                .focused($focused)
                .accessibilityLabel(label).accessibilityIdentifier("books.field." + label)
                #if os(iOS)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if focused {
                            Spacer()
                            Button("Done") { focused = false }
                                .font(DesignTokens.functionalFont(size: 16))
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityIdentifier("books.keyboardDone")
                        }
                    }
                }
                #endif
        }
    }
}
struct BooksErrorMessage: View {
    @EnvironmentObject var model: BooksModel
    var body: some View { if let error = model.error { StatePresentation(kind: .error, title: "Change not saved", message: error) } }
}
