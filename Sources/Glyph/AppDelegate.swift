import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        VisionProcessor.warmUp()
        installEditMenu()

        let controller = MenuBarController()
        menuBarController = controller

        KeyboardShortcuts.onKeyDown(for: .capture) { [weak controller] in
            controller?.startCapture()
        }
    }

    /// As an accessory (menu-bar-only) app, Glyph has no `mainMenu` by
    /// default. Standard shortcuts like Cmd+W and Cmd+A/C/V/Z route through
    /// the app's menu key equivalents before falling back to the responder
    /// chain, so without one, Close and Select All etc. silently don't work
    /// in Glyph's windows. This menu is never shown (no menu bar for an
    /// accessory app) — it exists only to wire up those key equivalents.
    private func installEditMenu() {
        let mainMenu = NSMenu()

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(
            withTitle: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
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
