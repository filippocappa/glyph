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
                    .foregroundStyle(.secondary)
                TextField("Search history", text: $searchText)
                    .textFieldStyle(.plain)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

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
            }
        }
        .frame(width: 360, height: 440)
        .background(VisualEffectBackground(material: .sidebar))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear { searchFocused = true }
    }

    private func row(for entry: HistoryEntry) -> some View {
        RowButton(entry: entry, isCopied: copiedID == entry.id) {
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
                    Text(entry.text)
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
}
