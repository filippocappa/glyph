import AppKit
import KeyboardShortcuts
import SwiftUI

/// Whether a shortcut recording is in progress anywhere in the app.
///
/// Window controllers consult this so Escape can mean "cancel the recording"
/// while one is running and "close the window" the rest of the time, without
/// depending on the undefined ordering between two local event monitors.
@MainActor
final class ShortcutRecorderState: ObservableObject {
    static let shared = ShortcutRecorderState()

    @Published fileprivate(set) var isRecording = false

    private init() {}
}

/// Owns the key monitor and the in-flight recording, so teardown is
/// deterministic rather than riding on a SwiftUI view struct's lifetime.
@MainActor
private final class ShortcutRecorderModel: ObservableObject {
    @Published private(set) var shortcut: KeyboardShortcuts.Shortcut?
    @Published private(set) var isRecording = false

    private let name: KeyboardShortcuts.Name
    private var shortcutBeforeRecording: KeyboardShortcuts.Shortcut?
    private var monitor: Any?

    /// Bare function keys are the one combination worth allowing without a
    /// Command/Option/Control in it — everything else needs a real modifier,
    /// since Shift alone can't carry a global hotkey.
    private static let functionKeys: Set<KeyboardShortcuts.Key> = [
        .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
        .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20
    ]

    init(name: KeyboardShortcuts.Name) {
        self.name = name
        shortcut = KeyboardShortcuts.getShortcut(for: name)
    }

    func startRecording(clearingExisting: Bool) {
        guard !isRecording else {
            cancelRecording()
            return
        }

        // Unregister the current hotkey first, or it fires while the user is
        // trying to type its replacement.
        KeyboardShortcuts.disable(name)

        if clearingExisting {
            apply(nil)
        }

        shortcutBeforeRecording = shortcut
        isRecording = true
        ShortcutRecorderState.shared.isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    /// Ends recording and restores whatever shortcut was in place when it
    /// started — including "none", if the user cleared it on the way in.
    func cancelRecording() {
        guard isRecording else { return }
        apply(shortcutBeforeRecording)
        endRecording()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }

        // Any click — on this badge or anywhere else — ends the recording, and
        // is swallowed so it can't also re-trigger the badge it landed on.
        guard event.type == .keyDown else {
            cancelRecording()
            return nil
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 53, modifiers.isEmpty { // Escape
            cancelRecording()
            return nil
        }

        if event.keyCode == 51, modifiers.isEmpty { // Delete / Backspace
            apply(nil)
            endRecording()
            return nil
        }

        guard let recorded = KeyboardShortcuts.Shortcut(event: event), isUsable(recorded, modifiers: modifiers) else {
            NSSound.beep()
            return nil
        }

        apply(recorded)
        endRecording()
        return nil
    }

    private func isUsable(_ shortcut: KeyboardShortcuts.Shortcut, modifiers: NSEvent.ModifierFlags) -> Bool {
        if !modifiers.subtracting([.shift, .function]).isEmpty {
            return true
        }
        return shortcut.key.map(Self.functionKeys.contains) ?? false
    }

    private func apply(_ newValue: KeyboardShortcuts.Shortcut?) {
        shortcut = newValue
        KeyboardShortcuts.setShortcut(newValue, for: name)
    }

    private func endRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        ShortcutRecorderState.shared.isRecording = false
        KeyboardShortcuts.enable(name)
    }
}

/// A shortcut recorder built as a plain button rather than a text field.
///
/// `KeyboardShortcuts.Recorder` is an `NSSearchField` subclass, which brought
/// three problems with it: its text was mouse-selectable, it took first
/// responder as soon as the window opened (so opening Settings silently armed
/// recording), and it captured keystrokes from that moment on. Nothing here is
/// a text field, so there is no selection, no first responder to steal, and no
/// key monitor at all until the user explicitly clicks to record.
struct ShortcutRecorder: View {
    @StateObject private var model: ShortcutRecorderModel
    @State private var isHoveringBadge = false

    init(for name: KeyboardShortcuts.Name) {
        _model = StateObject(wrappedValue: ShortcutRecorderModel(name: name))
    }

    var body: some View {
        HStack(spacing: 6) {
            Button { model.startRecording(clearingExisting: false) } label: {
                badge
            }
            .buttonStyle(.plain)
            .onHover { isHoveringBadge = $0 }
            .help(model.isRecording ? "Press a key combination, or Escape to cancel" : "Click to record a new shortcut")

            if model.shortcut != nil, !model.isRecording {
                Button { model.startRecording(clearingExisting: true) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear this shortcut and record a new one")
            }
        }
        .onDisappear { model.cancelRecording() }
        // A window closing out from under an in-progress recording has to tear
        // the monitor down too, and `onDisappear` isn't guaranteed to run for a
        // hosting controller that outlives its window.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            model.cancelRecording()
        }
    }

    private var badge: some View {
        Text(badgeTitle)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(model.isRecording ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minWidth: 104)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(isHoveringBadge ? 0.16 : 0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: model.isRecording ? 1.5 : 0)
            )
            .contentShape(Capsule(style: .continuous))
    }

    private var badgeTitle: String {
        if model.isRecording {
            return "Press Shortcut…"
        }
        if let shortcut = model.shortcut {
            return shortcut.description
        }
        return "Record Shortcut"
    }
}
