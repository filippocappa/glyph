import AppKit

/// A window that always reports itself as key- and main-capable.
///
/// `NSWindow` derives both from the style mask, so a window without a
/// titlebar — or one whose titlebar is transparent and button-less — can end
/// up refusing main status. macOS Sequoia's window manager (Control+Globe+C
/// and friends) and third-party managers like Raycast skip any window that
/// can't become main, which is why Glyph's panels used to be invisible to
/// them.
final class GlyphWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Brings the app's key window forward without ever leaving the accessory
/// (menu-bar-only) activation policy.
///
/// `GlyphWindow`'s `canBecomeKey`/`canBecomeMain` overrides are what make a
/// window visible to Control+Globe+C and Raycast-style managers — the app's
/// own activation policy is irrelevant to that. Switching to `.regular` here
/// was tried at one point but only added an unwanted Dock icon, so windows
/// stay on top of a purely accessory app, the same as Hum.
@MainActor
enum AppActivation {
    /// Call once per window as it is first put on screen.
    static func beginPresenting() {
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Call once per window as it closes.
    static func endPresenting() {}
}
