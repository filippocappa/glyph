import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var escMonitor: Any?
    private var resignKeyCloseTimer: Timer?

    convenience init() {
        let hosting = NSHostingController(rootView: SettingsView())
        // `SettingsView` hugs its own content (fixed width, no maxHeight),
        // so this is its real natural size — measured once, up front, so the
        // window is never a guessed constant that's too tall (dead space) or
        // too short (a clipped last row).
        let fittingSize = hosting.view.fittingSize
        // The window's own contentRect is the source of truth for size from
        // here on; without this the hosting controller would keep re-deriving
        // a "preferred content size" from the SwiftUI content and resizing
        // the window to match on every future update.
        hosting.sizingOptions = []

        // Titled (so the window manager still sees an ordinary app window)
        // but with a transparent, title-less bar over full-size content: one
        // unified glass panel with the traffic lights floating on it.
        let window = GlyphWindow(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // macOS's automatic window-state restoration would otherwise bring
        // back a frame from before this window had size bounds at all.
        window.isRestorable = false
        window.collectionBehavior = [.moveToActiveSpace, .participatesInCycle, .fullScreenAuxiliary]

        // `fittingSize` was measured before the view was ever windowed, so it
        // doesn't include the titlebar's safe-area inset that `SettingsView`
        // will actually be pushed down by once it's really hosted in a
        // `.fullSizeContentView` window. Measure that inset directly from
        // this window (a fixed, OS-defined height, independent of content)
        // and add it, rather than guess at a number that goes stale the
        // moment a row is added or removed.
        let titlebarHeight = window.frame.height - window.contentLayoutRect.height
        // A few points of slack: `fittingSize`, measured before the view was
        // windowed, ran slightly short and clipped the footer's bottom edge.
        let contentSize = NSSize(width: fittingSize.width, height: fittingSize.height + titlebarHeight + 20)

        // Fixed size: `.resizable` is absent from the style mask, and
        // identical min/max bounds say so to anything that asks anyway.
        window.setContentSize(contentSize)
        window.minSize = contentSize
        window.maxSize = contentSize

        // Nothing in this window should take focus on open — the shortcut
        // recorder used to, which silently armed recording.
        window.initialFirstResponder = nil

        self.init(window: window)
        window.delegate = self
    }

    func show() {
        guard let window else { return }

        let wasVisible = window.isVisible
        if !wasVisible {
            // Raise out of `.accessory` before ordering the window in, so the
            // window manager sees it belonging to a foreground app.
            AppActivation.beginPresenting()
            window.center()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        installEscMonitor()
    }

    /// Escape closes the window — unless a shortcut recording is in progress,
    /// in which case Escape belongs to the recorder as its cancel key.
    /// (Cmd+W is handled by the File ▸ Close menu item instead.)
    private func installEscMonitor() {
        removeEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                self.window?.isKeyWindow == true,
                event.keyCode == 53,
                !ShortcutRecorderState.shared.isRecording
            else {
                return event
            }
            self.window?.close()
            return nil
        }
    }

    private func removeEscMonitor() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
        }
        escMonitor = nil
    }

    func windowWillClose(_ notification: Notification) {
        removeEscMonitor()
        resignKeyCloseTimer?.invalidate()
        AppActivation.endPresenting()
    }

    /// Losing focus without being dismissed means the user clicked away —
    /// close the window shortly after, the way a HUD/utility panel should,
    /// unless it becomes key again in the meantime.
    func windowDidResignKey(_ notification: Notification) {
        resignKeyCloseTimer?.invalidate()
        resignKeyCloseTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.window?.isKeyWindow != true else { return }
                self.window?.close()
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        resignKeyCloseTimer?.invalidate()
        resignKeyCloseTimer = nil
    }
}
