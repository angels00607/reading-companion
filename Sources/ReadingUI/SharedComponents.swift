import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct PreviewBook: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let coverSymbol: String?
    public let detail: String?
    public let coverURL: URL?
    public init(id: String, title: String, author: String, coverSymbol: String? = nil, detail: String? = nil, coverURL: URL? = nil) {
        self.id = id; self.title = title; self.author = author; self.coverSymbol = coverSymbol; self.detail = detail; self.coverURL = coverURL
    }
}

public struct BookCover: View {
    @Environment(\.colorScheme) private var scheme
    private let title: String
    private let symbol: String?
    private let width: CGFloat
    private let url: URL?
    public init(title: String, symbol: String? = nil, width: CGFloat = 54, url: URL? = nil) {
        self.title = title; self.symbol = symbol; self.width = width; self.url = url
    }
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.coverRadius)
                .fill(DesignTokens.blueSurface(scheme))
            Image(systemName: symbol ?? "book.closed")
                .font(.title2)
                .foregroundStyle(DesignTokens.primary(scheme))
                .accessibilityHidden(true)
            if let url {
                if url.isFileURL {
                    #if os(iOS)
                    if let image = UIImage(contentsOfFile: url.path) { Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true) }
                    #elseif os(macOS)
                    if let image = NSImage(contentsOf: url) { Image(nsImage: image).resizable().scaledToFit().accessibilityHidden(true) }
                    #endif
                } else {
                    AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { Color.clear }.accessibilityHidden(true)
                }
            }
        }
        .frame(width: width, height: width * 1.5)
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.coverRadius).stroke(DesignTokens.border(scheme)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cover for \(title)")
    }
}

public struct BookRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    public let book: PreviewBook
    public init(book: PreviewBook) { self.book = book }
    public var body: some View {
        ViewThatFits(in: .horizontal) {
            if !typeSize.isAccessibilitySize { HStack(alignment: .top, spacing: 12) { BookCover(title: book.title, symbol: book.coverSymbol, url: book.coverURL); metadata; Spacer(minLength: 0) } }
            VStack(alignment: .leading, spacing: 12) { BookCover(title: book.title, symbol: book.coverSymbol, url: book.coverURL); metadata }
        }
        .padding(DesignTokens.Spacing.medium)
        .background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title), by \(book.author)" + (book.detail.map { ", \($0)" } ?? ""))
        .accessibilityIdentifier("phase1.bookRow")
    }
    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title).font(DesignTokens.functionalFont(size: 17, relativeTo: .headline, weight: .semiBold)).foregroundStyle(DesignTokens.text(scheme)).fixedSize(horizontal: false, vertical: true)
            Text(book.author).font(DesignTokens.functionalFont(size: 14, relativeTo: .subheadline)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
            if let detail = book.detail { Text(detail).font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

public enum StatusTone: Sendable { case neutral, active, special, warning }
public struct StatusChip: View {
    @Environment(\.colorScheme) private var scheme
    public let text: String; public let symbol: String; public let tone: StatusTone
    public init(_ text: String, symbol: String, tone: StatusTone = .neutral) { self.text = text; self.symbol = symbol; self.tone = tone }
    private var color: Color { tone == .special ? DesignTokens.secondary(scheme) : DesignTokens.primary(scheme) }
    private var fill: Color { tone == .special ? DesignTokens.plumSurface(scheme) : DesignTokens.blueSurface(scheme) }
    public var body: some View {
        Label(text, systemImage: symbol).font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .medium))
            .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 6).background(fill, in: Capsule())
            .accessibilityLabel(text)
    }
}

public enum ReadingProgressValue: Equatable, Sendable {
    case pages(current: Int?, total: Int?)
    case percentage(Double?)
    public var fraction: Double? {
        switch self {
        case let .pages(current?, total?) where total > 0: min(max(Double(current) / Double(total), 0), 1)
        case let .percentage(value?): min(max(value / 100, 0), 1)
        default: nil
        }
    }
    public var label: String {
        switch self {
        case let .pages(current, total):
            if let current, let total { return "Page \(current) of \(total)" }
            if let current { return "Page \(current), total unknown" }
            return "Page progress unknown"
        case let .percentage(value): return value.map { "\($0.formatted(.number.precision(.fractionLength(0...8)))) percent" } ?? "Percentage unknown"
        }
    }
}

public struct ReadingProgressBar: View {
    @Environment(\.colorScheme) private var scheme
    public let value: ReadingProgressValue; public let showsLabel: Bool
    public init(_ value: ReadingProgressValue, showsLabel: Bool = true) { self.value = value; self.showsLabel = showsLabel }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsLabel { Text(value.label).font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme)) }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignTokens.border(scheme))
                    Capsule().fill(DesignTokens.primary(scheme)).frame(width: proxy.size.width * (value.fraction ?? 0))
                }
            }.frame(height: 10)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Reading progress").accessibilityValue(value.label)
        .accessibilityIdentifier("phase1.progressBar")
    }
}

public enum AppButtonKind { case primary, secondary, tertiary }
public struct AppButton: View {
    @Environment(\.colorScheme) private var scheme
    public let title: String; public let symbol: String?; public let kind: AppButtonKind; public let action: () -> Void
    public init(_ title: String, symbol: String? = nil, kind: AppButtonKind = .primary, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.kind = kind; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            Group { if let symbol { Label(title, systemImage: symbol) } else { Text(title) } }
                .font(DesignTokens.functionalFont(size: 16, relativeTo: .body, weight: .semiBold))
                .frame(maxWidth: kind == .tertiary ? nil : .infinity, minHeight: 48)
                .padding(.horizontal, kind == .tertiary ? 4 : 16)
                .foregroundStyle(kind == .primary ? DesignTokens.onPrimary(scheme) : DesignTokens.primary(scheme))
                .background(kind == .primary ? DesignTokens.primary(scheme) : Color.clear,
                            in: RoundedRectangle(cornerRadius: DesignTokens.buttonRadius))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.buttonRadius)
                    .stroke(kind == .secondary ? DesignTokens.border(scheme) : Color.clear))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).frame(minHeight: DesignTokens.minimumTouchTarget)
    }
}

public struct FilterChip: View {
    @Environment(\.colorScheme) private var scheme
    public let title: String; @Binding public var isSelected: Bool
    public init(_ title: String, isSelected: Binding<Bool>) { self.title = title; _isSelected = isSelected }
    public var body: some View {
        Button { isSelected.toggle() } label: {
            HStack(spacing: 6) {
                if isSelected { Image(systemName: "checkmark").accessibilityHidden(true) }
                Text(title)
            }.font(DesignTokens.functionalFont(size: 14, relativeTo: .body, weight: .medium))
                .lineLimit(1).fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 12).frame(minHeight: 44)
                .foregroundStyle(isSelected ? DesignTokens.primary(scheme) : DesignTokens.secondaryText(scheme))
                .background(isSelected ? DesignTokens.blueSurface(scheme) : DesignTokens.surface(scheme), in: Capsule())
                .overlay(Capsule().stroke(DesignTokens.border(scheme)))
        }.buttonStyle(.plain).accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

public struct AppSegmentedControl<Option: Hashable>: View {
    @Environment(\.colorScheme) private var scheme
    public let options: [(Option, String)]; @Binding public var selection: Option
    public init(options: [(Option, String)], selection: Binding<Option>) { self.options = options; _selection = selection }
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { option, label in
                Button { selection = option } label: {
                    Text(label).font(DesignTokens.functionalFont(size: 14, relativeTo: .body, weight: selection == option ? .semiBold : .medium))
                        .frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 6)
                        .background(selection == option ? DesignTokens.surface(scheme) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()).foregroundStyle(selection == option ? DesignTokens.text(scheme) : DesignTokens.secondaryText(scheme))
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }.padding(4).background(DesignTokens.blueSurface(scheme), in: RoundedRectangle(cornerRadius: 12))
    }
}

public struct AppBottomSheet<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    public let title: String; @ViewBuilder public let content: Content
    public init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    public var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(DesignTokens.secondaryText(scheme).opacity(0.45)).frame(width: 36, height: 5).accessibilityHidden(true)
            Text(title).font(DesignTokens.functionalFont(size: 22, relativeTo: .title2, weight: .semiBold)).frame(maxWidth: .infinity, alignment: .leading)
            content
        }.padding(20).background(DesignTokens.surface(scheme), in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("phase1.bottomSheet")
    }
}

public struct AppToast: View {
    @Environment(\.colorScheme) private var scheme
    public let message: String; public let actionTitle: String?; public let action: (() -> Void)?
    public init(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) { self.message = message; self.actionTitle = actionTitle; self.action = action }
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(DesignTokens.primary(scheme)).accessibilityHidden(true)
            Text(message).font(DesignTokens.functionalFont(size: 14)).fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let actionTitle, let action { Button(actionTitle, action: action).font(DesignTokens.functionalFont(size: 14, weight: .semiBold)).frame(minHeight: 44) }
        }.padding(.horizontal, 16).padding(.vertical, 8).background(DesignTokens.raisedSurface(scheme), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignTokens.border(scheme))).accessibilityElement(children: .combine)
            .accessibilityIdentifier("phase1.toast")
    }
}

public struct SkeletonRow: View {
    @Environment(\.colorScheme) private var scheme
    public init() {}
    public var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(DesignTokens.border(scheme)).frame(width: 54, height: 81)
            VStack(alignment: .leading, spacing: 9) {
                RoundedRectangle(cornerRadius: 4).fill(DesignTokens.border(scheme)).frame(maxWidth: 190).frame(height: 15)
                RoundedRectangle(cornerRadius: 4).fill(DesignTokens.border(scheme)).frame(maxWidth: 125).frame(height: 12)
            }
        }.redacted(reason: .placeholder).accessibilityLabel("Loading book")
            .accessibilityIdentifier("phase1.skeleton")
    }
}

public enum StatePresentationKind { case empty, error, offline }
public struct StatePresentation: View {
    @Environment(\.colorScheme) private var scheme
    public let kind: StatePresentationKind; public let title: String; public let message: String
    public init(kind: StatePresentationKind, title: String, message: String) { self.kind = kind; self.title = title; self.message = message }
    private var symbol: String { switch kind { case .empty: "books.vertical"; case .error: "exclamationmark.triangle"; case .offline: "wifi.slash" } }
    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title).foregroundStyle(kind == .error ? DesignTokens.error(scheme) : DesignTokens.primary(scheme)).accessibilityHidden(true)
            Text(title).font(DesignTokens.functionalFont(size: 18, relativeTo: .headline, weight: .semiBold))
            Text(message).font(DesignTokens.functionalFont(size: 14)).foregroundStyle(DesignTokens.secondaryText(scheme)).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.vertical, 12).accessibilityElement(children: .combine)
    }
}

public struct OfflineBanner: View {
    @Environment(\.colorScheme) private var scheme
    public init() {}
    public var body: some View {
        Label("Offline — local reading tools remain available", systemImage: "wifi.slash")
            .font(DesignTokens.functionalFont(size: 13, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.text(scheme))
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            .padding(10).background(DesignTokens.blueSurface(scheme))
    }
}

public struct DataChangeReview: View {
    @Environment(\.colorScheme) private var scheme
    public let field: String; public let current: String; public let proposed: String; public let source: String
    public let accept: () -> Void; public let keep: () -> Void; public let edit: () -> Void
    public let canAccept: Bool; public let canEdit: Bool
    public init(field: String, current: String, proposed: String, source: String, canAccept: Bool = true, canEdit: Bool = true, accept: @escaping () -> Void = {}, keep: @escaping () -> Void = {}, edit: @escaping () -> Void = {}) {
        self.field = field; self.current = current; self.proposed = proposed; self.source = source; self.accept = accept; self.keep = keep; self.edit = edit
        self.canAccept=canAccept; self.canEdit=canEdit
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(field).font(DesignTokens.functionalFont(size: 18, relativeTo: .headline, weight: .semiBold))
            comparison("Current", current, color: DesignTokens.blueSurface(scheme))
            comparison("Proposed", proposed, color: DesignTokens.plumSurface(scheme))
            Label("Source: \(source)", systemImage: "link").font(DesignTokens.functionalFont(size: 12, relativeTo: .caption)).foregroundStyle(DesignTokens.secondaryText(scheme)).padding(.top, -2)
            ViewThatFits(in: .horizontal) {
                HStack { AppButton("Keep", kind: .secondary, action: keep); AppButton("Accept", action: accept).disabled(!canAccept); AppButton("Edit", kind: .tertiary, action: edit).disabled(!canEdit) }
                VStack(spacing: 8) { AppButton("Keep", kind: .secondary, action: keep); AppButton("Accept", action: accept).disabled(!canAccept); AppButton("Edit", kind: .tertiary, action: edit).disabled(!canEdit) }
            }
        }.padding(16).background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.cardRadius).stroke(DesignTokens.border(scheme)))
            .accessibilityIdentifier("phase1.dataChangeReview")
    }
    private func comparison(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(label).font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .medium)); Text(value).font(DesignTokens.functionalFont(size: 15)).fixedSize(horizontal: false, vertical: true) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(color, in: RoundedRectangle(cornerRadius: 10))
    }
}

public struct AttentionRow: View {
    @Environment(\.colorScheme) private var scheme
    public let title: String; public let detail: String; public let category: String
    public init(title: String, detail: String, category: String) { self.title = title; self.detail = detail; self.category = category }
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(DesignTokens.secondary(scheme)).frame(width: 44, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(DesignTokens.functionalFont(size: 16, relativeTo: .headline, weight: .semiBold))
                Text(detail).font(DesignTokens.functionalFont(size: 14)).foregroundStyle(DesignTokens.secondaryText(scheme)).fixedSize(horizontal: false, vertical: true)
                Text(category).font(DesignTokens.functionalFont(size: 12, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondary(scheme))
            }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(DesignTokens.secondaryText(scheme)).accessibilityHidden(true)
        }.padding(.vertical, 8).accessibilityElement(children: .combine).accessibilityHint("Opens review")
            .accessibilityIdentifier("phase1.attentionRow")
    }
}

public struct AccessibleChartDatum: Identifiable, Sendable { public let id: String; public let label: String; public let value: Double; public init(_ label: String, value: Double) { id = label; self.label = label; self.value = value } }
public struct AccessibleBarChart: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    public let title: String; public let data: [AccessibleChartDatum]
    public init(title: String, data: [AccessibleChartDatum]) { self.title = title; self.data = data }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(DesignTokens.functionalFont(size: 18, relativeTo: .headline, weight: .semiBold))
            ForEach(data) { item in chartRow(item) }
        }.accessibilityElement(children: .contain).accessibilityLabel(title)
            .accessibilityIdentifier("phase1.accessibleChart")
    }
    private func chartRow(_ item: AccessibleChartDatum) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { HStack { Text(item.label); Spacer(); Text(item.value.formatted()).monospacedDigit() }; GeometryReader { proxy in Capsule().fill(DesignTokens.primary(scheme)).frame(width: proxy.size.width * normalized(item.value)) }.frame(height: 10) }
            } else {
                HStack { Text(item.label).frame(width: 48, alignment: .leading); GeometryReader { proxy in Capsule().fill(DesignTokens.primary(scheme)).frame(width: proxy.size.width * normalized(item.value)) }.frame(height: 10); Text(item.value.formatted()).monospacedDigit() }
            }
        }.font(DesignTokens.functionalFont(size: 13, relativeTo: .caption)).frame(minHeight: 44)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(item.label), \(item.value.formatted())")
    }
    private func normalized(_ value: Double) -> Double { let maximum = data.map(\.value).max() ?? 1; return maximum > 0 ? max(0, value / maximum) : 0 }
}

public struct FeatureCelebration: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    public let eyebrow: String; public let title: String; public let message: String; public let dismiss: () -> Void
    public init(eyebrow: String, title: String, message: String, dismiss: @escaping () -> Void = {}) { self.eyebrow = eyebrow; self.title = title; self.message = message; self.dismiss = dismiss }
    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark.fill").font(.largeTitle).foregroundStyle(DesignTokens.secondary(scheme)).overlay(alignment: .topTrailing) { Image(systemName: "sparkle").foregroundStyle(DesignTokens.primary(scheme)).offset(x: 10, y: -8) }.accessibilityHidden(true)
            Text(eyebrow).font(DesignTokens.functionalFont(size: 13, relativeTo: .caption, weight: .medium)).foregroundStyle(DesignTokens.secondary(scheme))
            Text(title).font(DesignTokens.celebrationAccent(size: 32)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(message).font(DesignTokens.functionalFont(size: 15)).foregroundStyle(DesignTokens.secondaryText(scheme)).multilineTextAlignment(.center)
            AppButton("Continue", action: dismiss)
        }.padding(24).background(DesignTokens.surface(scheme), in: RoundedRectangle(cornerRadius: 22))
            .scaleEffect(reduceMotion || visible ? 1 : 0.96).opacity(visible ? 1 : 0)
            .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { visible = true } }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("phase1.celebration")
    }
}
