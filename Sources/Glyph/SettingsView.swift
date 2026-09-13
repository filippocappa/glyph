import KeyboardShortcuts
import SwiftUI
import Vision

struct SettingsView: View {
    @AppStorage(SettingsKeys.recognitionLanguage) private var recognitionLanguage = SettingsKeys.automaticLanguage
    @State private var shortcutJustChanged = false
    @State private var showClearHistoryConfirmation = false

    private var availableLanguages: [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let languages = (try? request.supportedRecognitionLanguages()) ?? []
        return languages.sorted {
            displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 2)

            Form {
                Section {
                    LabeledContent("Shortcut") {
                        HStack(spacing: 6) {
                            if shortcutJustChanged {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .transition(.opacity.combined(with: .scale))
                            }
                            KeyboardShortcuts.Recorder(for: .capture) { _ in
                                withAnimation { shortcutJustChanged = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                    withAnimation { shortcutJustChanged = false }
                                }
                            }
                        }
                    }

                    Text("Click the field — it will say “Press Shortcut” while recording — then press a key combination.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LabeledContent("Language") {
                        Picker("", selection: $recognitionLanguage) {
                            Text("Automatic").tag(SettingsKeys.automaticLanguage)
                            ForEach(availableLanguages, id: \.self) { code in
                                Text(displayName(for: code)).tag(code)
                            }
                        }
                        .labelsHidden()
                    }
                } footer: {
                    Text("Automatic detects the language on each capture. Pinning a language can improve accuracy for short or single-language text.")
                }

                Section {
                    LabeledContent("Capture History") {
                        Button("Clear History…", role: .destructive) {
                            showClearHistoryConfirmation = true
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)

            footer
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(VisualEffectBackground(material: .sidebar))
        .confirmationDialog(
            "Clear all capture history?",
            isPresented: $showClearHistoryConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                HistoryStore.shared.clear()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private var footer: some View {
        HStack {
            Link(destination: URL(string: "https://github.com/filippocappa/glyph")!) {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .font(.caption)

            Spacer()

            Text("Made with ❤️ by Filippo Cappa")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func displayName(for code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }
}
