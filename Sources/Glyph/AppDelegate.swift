import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        VisionProcessor.warmUp()

        let controller = MenuBarController()
        menuBarController = controller

        KeyboardShortcuts.onKeyDown(for: .capture) { [weak controller] in
            controller?.startCapture()
        }
    }

    /// Handles the case where the user relaunches Glyph (Finder, Spotlight,
    /// Raycast) while it is already running as a background agent.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        UserDefaults.standard.set(true, forKey: SettingsKeys.showMenuBarIcon)
        menuBarController?.showStatusItem()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
