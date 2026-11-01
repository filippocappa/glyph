import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController, NSWindowDelegate {
    private static let defaultSize = NSSize(width: 440, height: 560)
    private static let minSize = NSSize(width: 360, height: 400)
    private static let maxSize = NSSize(width: 650, height: 850)

    private var escMonitor: Any?
    private var resignKeyCloseTimer: Timer?

    convenience init() {
        let hosting = NSHostingController(rootView: HistoryView())
        // The window drives the size here, not the SwiftUI content — without
        // this the hosting controller resizes the window back to its content's
        // preferred size, fighting both the user's resizing and the min/max
        // bounds below (which is what collapsed this window to a tiny box).
        hosting.sizingOptions = []

        // A Spotlight-style HUD: no title, no traffic lights, no titlebar
        // separator — but still a real titled window rather than a
        // `.borderless` one, because borderless windows are skipped by the
        // native window-management shortcuts and by Raycast, and lose the
        // system's rounded corners and shadow.
        let window = GlyphWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = "History"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // macOS's automatic window-state restoration would otherwise bring
        // back a frame from before this window had size bounds at all.
        window.isRestorable = false
        window.collectionBehavior = [.moveToActiveSpace, .participatesInCycle, .fullScreenAuxiliary]

        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }

        // `.fullSizeContentView` makes the frame and content rects equal, so
        // these bounds are also the content's bounds.
        window.setContentSize(Self.defaultSize)
        window.minSize = Self.minSize
        window.maxSize = Self.maxSize

        self.init(window: window)
        window.delegate = self
    }

    func show() {
        guard let window else { return }

        if !window.isVisible {
            // Raise out of `.accessory` before ordering the window in, so the
            // window manager sees it belonging to a foreground app.
            AppActivation.beginPresenting()
            // Re-assert the bounds: a window restored from a previous session
            // can come back outside them.
            window.setContentSize(
                NSSize(
                    width: min(max(window.frame.width, Self.minSize.width), Self.maxSize.width),
                    height: min(max(window.frame.height, Self.minSize.height), Self.maxSize.height)
                )
            )
            window.center()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        window.makeKeyAndOrderFront(nil)
        installEscMonitor()
    }

    /// Escape closes this window, the way a quick-lookup panel should — and
    /// it is the only way to close it, since there is no close button.
    /// (Cmd+W is handled by the File ▸ Close menu item instead.)
    private func installEscMonitor() {
        removeEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                self.window?.isKeyWindow == true,
                event.keyCode == 53
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

    // MARK: - Size bounds

    /// `minSize`/`maxSize` only govern the user's own resize drags — a frame
    /// set programmatically (by SwiftUI, by window restoration, or by an
    /// accessibility client like a window manager) sails straight past them,
    /// which is how this window ended up collapsed into an unreadable box.
    /// These two clamp every path.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        Self.clamped(frameSize)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window else { return }

        let clamped = Self.clamped(window.frame.size)
        guard clamped != window.frame.size else { return }

        var frame = window.frame
        // Resize from the top-left, the anchor AppKit uses, so the window
        // doesn't appear to jump when a clamp kicks in.
        frame.origin.y += frame.height - clamped.height
        frame.size = clamped
        window.setFrame(frame, display: true)
    }

    private static func clamped(_ size: NSSize) -> NSSize {
        NSSize(
            width: min(max(size.width, minSize.width), maxSize.width),
            height: min(max(size.height, minSize.height), maxSize.height)
        )
    }
}
