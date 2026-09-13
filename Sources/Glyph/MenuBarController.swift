import AppKit
import LaunchAtLogin

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let captureManager = CaptureManager()
    private var settingsWindowController: SettingsWindowController?
    private var historyWindowController: HistoryWindowController?

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [
            SettingsKeys.keepLineBreaks: true,
            SettingsKeys.showMenuBarIcon: true,
            SettingsKeys.recognitionLanguage: SettingsKeys.automaticLanguage
        ])

        if UserDefaults.standard.bool(forKey: SettingsKeys.showMenuBarIcon) {
            createStatusItem()
        }
    }

    // MARK: - Status item lifecycle

    func showStatusItem() {
        guard statusItem == nil else { return }
        createStatusItem()
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Glyph")?
                .withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            } else {
                // Guaranteed fallback so the status item is never blank.
                button.title = "Glyph"
            }
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func hideStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let captureItem = NSMenuItem(
            title: "Capture Text / QR",
            action: #selector(captureRequested),
            keyEquivalent: "2"
        )
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        let historyItem = NSMenuItem(
            title: "History…",
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let keepLineBreaksItem = NSMenuItem(
            title: "Keep Line Breaks",
            action: #selector(toggleKeepLineBreaks),
            keyEquivalent: ""
        )
        keepLineBreaksItem.target = self
        menu.addItem(keepLineBreaksItem)

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        let showIconItem = NSMenuItem(
            title: "Show Menu Bar Icon",
            action: #selector(toggleShowMenuBarIcon),
            keyEquivalent: ""
        )
        showIconItem.target = self
        menu.addItem(showIconItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Glyph",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items {
            switch item.action {
            case #selector(toggleKeepLineBreaks):
                item.state = UserDefaults.standard.bool(forKey: SettingsKeys.keepLineBreaks) ? .on : .off
            case #selector(toggleLaunchAtLogin):
                item.state = LaunchAtLogin.isEnabled ? .on : .off
            case #selector(toggleShowMenuBarIcon):
                item.state = UserDefaults.standard.bool(forKey: SettingsKeys.showMenuBarIcon) ? .on : .off
            default:
                break
            }
        }
    }

    // MARK: - Capture

    @objc private func captureRequested() {
        startCapture()
    }

    func startCapture() {
        captureManager.capture { [weak self] cgImage in
            guard let self else { return }
            guard let cgImage else {
                // User pressed Esc / cancelled the selection — no feedback needed.
                return
            }
            self.process(cgImage)
        }
    }

    private func process(_ cgImage: CGImage) {
        let keepLineBreaks = UserDefaults.standard.bool(forKey: SettingsKeys.keepLineBreaks)
        let storedLanguage = UserDefaults.standard.string(forKey: SettingsKeys.recognitionLanguage)
        let languageCode = (storedLanguage == SettingsKeys.automaticLanguage) ? nil : storedLanguage

        VisionProcessor.process(
            cgImage: cgImage,
            keepLineBreaks: keepLineBreaks,
            languageCode: languageCode
        ) { [weak self] result in
            self?.handleResult(result)
        }
    }

    private func handleResult(_ result: RecognitionResult?) {
        guard let result, !result.value.isEmpty else {
            handleFailure()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result.value, forType: .string)

        HistoryStore.shared.add(result)

        let sound = NSSound(named: "Glass")
        sound?.volume = 0.5
        sound?.play()

        ToastController.shared.show(
            systemImage: result.isBarcode ? "qrcode" : "text.viewfinder",
            text: result.value
        )
    }

    /// Recognition found nothing usable — make that audible/visible instead
    /// of silently leaving the clipboard untouched.
    private func handleFailure() {
        let sound = NSSound(named: "Funk")
        sound?.volume = 0.5
        sound?.play()

        ToastController.shared.show(systemImage: "exclamationmark.triangle", text: "No text or code found")
    }

    // MARK: - Windows

    @objc private func showSettings() {
        let controller = settingsWindowController ?? SettingsWindowController()
        settingsWindowController = controller
        controller.show()
    }

    @objc private func showHistory() {
        let controller = historyWindowController ?? HistoryWindowController()
        historyWindowController = controller
        controller.show()
    }

    // MARK: - Toggles

    @objc private func toggleKeepLineBreaks() {
        let current = UserDefaults.standard.bool(forKey: SettingsKeys.keepLineBreaks)
        UserDefaults.standard.set(!current, forKey: SettingsKeys.keepLineBreaks)
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
    }

    @objc private func toggleShowMenuBarIcon() {
        let currentlyShown = UserDefaults.standard.bool(forKey: SettingsKeys.showMenuBarIcon)

        if currentlyShown {
            let alert = NSAlert()
            alert.messageText = "Hide Menu Bar Icon?"
            alert.informativeText = "To restore the icon later, simply launch Glyph again from your Applications folder."
            alert.addButton(withTitle: "Hide Icon")
            alert.addButton(withTitle: "Cancel")

            guard alert.runModal() == .alertFirstButtonReturn else { return }

            UserDefaults.standard.set(false, forKey: SettingsKeys.showMenuBarIcon)
            hideStatusItem()
        } else {
            UserDefaults.standard.set(true, forKey: SettingsKeys.showMenuBarIcon)
            showStatusItem()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
