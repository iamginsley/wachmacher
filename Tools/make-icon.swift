// Renders the Wachmacher app icon (1024×1024 PNG) following the macOS icon grid.
// Usage: swift Tools/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Squircle-ish rounded rect on the 824 pt macOS grid.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Drop shadow
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
NSColor.black.setFill()
path.fill()
NSGraphicsContext.restoreGraphicsState()

// Warm espresso → caramel gradient
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.98, green: 0.72, blue: 0.40, alpha: 1),
    NSColor(srgbRed: 0.82, green: 0.45, blue: 0.20, alpha: 1),
    NSColor(srgbRed: 0.42, green: 0.22, blue: 0.12, alpha: 1),
], atLocations: [0, 0.5, 1], colorSpace: .sRGB)!
gradient.draw(in: path, angle: -90)

// Soft top highlight
NSGraphicsContext.saveGraphicsState()
path.addClip()
let shine = NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!
shine.draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Cup with steam (SF Symbol), white with gentle shadow
let config = NSImage.SymbolConfiguration(pointSize: 470, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "cup.and.heat.waves.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let s = symbol.size
    let rect = NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2 - 10, width: s.width, height: s.height)
    NSGraphicsContext.saveGraphicsState()
    let glyphShadow = NSShadow()
    glyphShadow.shadowColor = NSColor(srgbRed: 0.25, green: 0.10, blue: 0.04, alpha: 0.45)
    glyphShadow.shadowOffset = NSSize(width: 0, height: -10)
    glyphShadow.shadowBlurRadius = 18
    glyphShadow.set()
    symbol.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
