# Glyph

A faster, zero-bloat, 100% native macOS menu bar utility for grabbing text and QR/barcodes off your screen — an alternative to TextSniper built entirely on Apple's own frameworks (Vision, AppKit), with no telemetry, no Electron, no background services beyond what you trigger yourself.

Press a global shortcut, drag a selection, and the recognized text (or barcode payload) is instantly on your clipboard.

## How it works

1. **Capture** — `⌘⇧2` triggers the native macOS screen selection crosshair (`screencapture -i`).
2. **Recognize** — the captured region is run through Apple's Vision framework:
   - Barcodes/QR codes are checked first; if a payload is found, it's used directly.
   - Otherwise, OCR text is extracted (`.accurate` recognition, language correction, automatic language detection).
3. **Deliver** — the result is copied to the clipboard, a system sound confirms the capture, a notification previews the first ~60 characters, and the capture is logged to History.

Pressing `Esc` during selection cancels cleanly — nothing is copied, nothing is left behind. If Vision finds nothing usable in the selection, Glyph beeps and notifies you instead of failing silently.

## Menu bar

- **Capture Text / QR** (`⌘⇧2`, customizable in Settings)
- **History…** — browse recent captures, click one to re-copy it, or clear the log
- **Keep Line Breaks** — toggle whether OCR lines are joined with newlines or spaces
- **Launch at Login**
- **Show Menu Bar Icon** — hide the status item; relaunch Glyph from Applications to bring it back
- **Settings…** (`⌘,`) — change the global shortcut and pin a recognition language
- **Quit Glyph** (`⌘Q`)

## Requirements

- macOS 14+
- Xcode 16+ / Swift 6 toolchain

## Build

Glyph is a Swift Package Manager executable — no `.xcodeproj` required.

```bash
swift build -c release
```

To install as a real menu bar app, package it into a signed `.app` bundle (this is required for `LaunchAtLogin`, notifications, and `LSUIElement` to work correctly — a raw CLI binary can't host any of those):

```bash
./Scripts/build_app.sh
mv Glyph.app /Applications/
open /Applications/Glyph.app
```

On first capture, macOS will prompt for **Screen Recording** permission (required by `screencapture -i`) — grant it in System Settings → Privacy & Security.

## Architecture

| File | Responsibility |
|---|---|
| `main.swift` | Entry point; forces `.accessory` activation policy (no Dock icon) |
| `AppDelegate.swift` | App lifecycle, reopen handling, notification authorization |
| `MenuBarController.swift` | Status item, menu, preference toggles, clipboard/sound/notification feedback |
| `CaptureManager.swift` | Drives `/usr/sbin/screencapture -i -x` and loads the result as a `CGImage` |
| `VisionProcessor.swift` | Runs `VNDetectBarcodesRequest` and `VNRecognizeTextRequest`, resolves barcode-first then reading-order OCR |
| `HistoryStore.swift` | Capped, `UserDefaults`-persisted log of recent captures |
| `HistoryView.swift` / `HistoryWindowController.swift` | SwiftUI History window |
| `SettingsView.swift` / `SettingsWindowController.swift` | SwiftUI Settings window (shortcut recorder, language picker) |
| `SettingsKeys.swift` | Shared `UserDefaults` key constants |

## Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — global hotkey recording
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) — login item management

## License

MIT
