import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared
    @State private var copiedID: HistoryEntry.ID?
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var filteredEntries: [HistoryEntry] {
        guard !searchText.isEmpty else { return store.entries }
        return store.entries.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search history", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 14)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)

            if filteredEntries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: store.entries.isEmpty ? "text.viewfinder" : "magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(.tertiary)
                    Text(store.entries.isEmpty ? "No captures yet" : "No matches")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredEntries) { entry in
                            row(for: entry)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                // The list takes every point the search field above doesn't,
                // so it grows and shrinks with the window.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // No traffic lights are visible on this window, so the content itself
        // ignores the titlebar's safe-area inset too — otherwise the search
        // bar sits under ~28pt of empty space meant for buttons that aren't
        // there. The search bar's own top padding below is all the clearance
        // it needs.
        .ignoresSafeArea()
        // HUD vibrancy, matching the titleless Spotlight-style panel this
        // window is configured as. Ignoring the safe area lets it bleed
        // all the way under the (hidden) titlebar instead of stopping short.
        .background(VisualEffectBackground(material: .hudWindow).ignoresSafeArea())
        .onAppear { searchFocused = true }
    }

    private func row(for entry: HistoryEntry) -> some View {
        RowButton(entry: entry, isCopied: copiedID == entry.id, highlight: searchText) {
            copy(entry)
        } onDelete: {
            store.remove(entry)
        }
    }

    private func copy(_ entry: HistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)

        withAnimation {
            copiedID = entry.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == entry.id {
                withAnimation { copiedID = nil }
            }
        }
    }
}

private struct RowButton: View {
    let entry: HistoryEntry
    let isCopied: Bool
    let highlight: String
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: entry.isBarcode ? "qrcode" : "text.viewfinder")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    highlightedText(entry.text, query: highlight)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isCopied {
                    Text("Copied")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.primary.opacity(0.06) : .clear)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy") { onCopy() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    /// Builds a `Text` with every case-insensitive occurrence of `query`
    /// bolded and tinted, so a search result shows *why* it matched.
    private func highlightedText(_ text: String, query: String) -> Text {
        guard !query.isEmpty else { return Text(text) }

        var result = Text("")
        var remaining = Substring(text)

        while let range = remaining.range(of: query, options: .caseInsensitive) {
            result = result + Text(remaining[remaining.startIndex..<range.lowerBound])
            result = result + Text(remaining[range]).bold().foregroundColor(.accentColor)
            remaining = remaining[range.upperBound...]
        }
        result = result + Text(remaining)
        return result
    }
}
