import AppKit

/// Menu bar cup: outline when off, filled when on, and – while a timer runs –
/// filled only up to the remaining share, so the cup empties as time passes.
@MainActor
enum CupIcon {
    private static var cache: [Double: NSImage] = [:]

    /// `level` nil = empty outline, 1 = full cup.
    static func image(level: Double?) -> NSImage {
        let key = level ?? -1
        if let cached = cache[key] { return cached }
        let image = render(level: level)
        cache[key] = image
        return image
    }

    private static func render(level: Double?) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        guard let outline = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)?
                .withSymbolConfiguration(config),
              let filled = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
        else { return NSImage() }

        let size = NSSize(width: ceil(max(outline.size.width, filled.size.width)),
                          height: ceil(max(outline.size.height, filled.size.height)))
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return outline }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = NSRect(origin: .zero, size: size)
        outline.draw(in: rect)
        if let level {
            if level >= 1 {
                filled.draw(in: rect)
            } else {
                // Saucer and cup bottom end near 32 % of the height, the liquid
                // line of a full cup sits near 62 % (tuned visually).
                let height = size.height * (0.32 + 0.30 * level)
                NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: height)).addClip()
                filled.draw(in: rect)
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}
