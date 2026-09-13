import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Belt-and-suspenders: guarantees no Dock icon / app switcher entry even if
// launched as a raw executable outside of a proper .app bundle (LSUIElement
// in Info.plist only takes effect once packaged into Glyph.app).
app.setActivationPolicy(.accessory)

app.run()
