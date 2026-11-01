import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI
import Vision

struct SettingsView: View {
    @AppStorage(SettingsKeys.recognitionLanguage) private var recognitionLanguage = SettingsKeys.automaticLanguage
    @AppStorage(SettingsKeys.keepLineBreaks) private var keepLineBreaks = true
    @AppStorage(SettingsKeys.showToast) private var showToast = true
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
        VStack(alignment: .leading, spacing: 12) {
            group {
                row("Capture Shortcut") {
                    ShortcutRecorder(for: .capture)
                }
                separator
                row("Language") {
                    languagePicker
                }
            }

            group {
                row("Launch at Login") {
                    LaunchAtLogin.Toggle("Launch at Login")
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                separator
                row("Keep Line Breaks") {
                    Toggle("Keep Line Breaks", isOn: $keepLineBreaks)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                separator
                row("Show Toast") {
                    Toggle("Show Toast", isOn: $showToast)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            group {
                row("History") {
                    Button("Clear Capture History…", role: .destructive) {
                        showClearHistoryConfirmation = true
                    }
                }
            }

            footer
        }
        .padding(.horizontal, 20)
        // AppKit already insets SwiftUI content by the titlebar's height (a
        // safe-area inset); this padding is the extra clearance below the
        // traffic lights on top of that.
        .padding(.top, 16)
        .padding(.bottom, 12)
        // A fixed width (not maxWidth: .infinity) and no maxHeight: this view
        // hugs its own content instead of stretching to fill — the window
        // controller measures that natural size once and sizes the window
        // to match exactly, instead of a hand-picked constant that's either
        // too tall (dead space at the bottom) or clips the last row.
        .frame(width: 460, alignment: .top)
        // Ignoring the safe area lets the vibrancy bleed all the way under
        // the titlebar; otherwise SwiftUI stops it below the traffic lights,
        // leaving the window's opaque background visible as a mismatched band.
        .background(VisualEffectBackground(material: .sidebar).ignoresSafeArea())
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

    // MARK: - Building blocks

    /// A macOS-style inset grouped card: related rows share one rounded
    /// background, separated internally by thin dividers.
    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
    }

    private var separator: some View {
        Divider().padding(.leading, 12)
    }

    private var languagePicker: some View {
        Picker("Language", selection: $recognitionLanguage) {
            Text("Automatic").tag(SettingsKeys.automaticLanguage)
            ForEach(availableLanguages, id: \.self) { code in
                Text(displayName(for: code)).tag(code)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    private var footer: some View {
        HStack {
            Link(destination: URL(string: "https://github.com/filippocappa/glyph")!) {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .font(.caption)

            Spacer()

            Text("\(appVersion) · Made with ❤️ by Filippo Cappa")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(shortVersion)"
    }

    private func displayName(for code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }
}
