import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init() {
        let hosting = NSHostingController(rootView: SettingsView())
        // Keeps the window sized to the SwiftUI content's actual ideal
        // size, rather than a manually guessed fixed frame that leaves
        // dead space when the content is shorter than the guess.
        hosting.sizingOptions = [.intrinsicContentSize]

        let window = NSWindow(contentViewController: hosting)
        window.title = "Glyph Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
