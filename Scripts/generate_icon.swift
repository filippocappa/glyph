#!/usr/bin/env swift
import AppKit

// Renders a simple native-style app icon (rounded-square gradient + SF Symbol)
// at every size macOS expects, into Resources/AppIcon.iconset, ready for
// `iconutil -c icns`.

let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

let outputDir = "Resources/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.19, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.06, alpha: 1)
    ])
    gradient?.draw(in: path, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        let origin = NSPoint(x: (size - symbolSize.width) / 2, y: (size - symbolSize.height) / 2)
        symbol.draw(in: NSRect(origin: origin, size: symbolSize))
    }

    image.unlockFocus()
    return image
}

for entry in sizes {
    let image = makeIcon(size: entry.size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else { continue }

    let path = "\(outputDir)/\(entry.name).png"
    try? png.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path)")
}
