import AppKit
import CatCore

/// Small code-drawn toys; the cats use LuizMelo’s CC0 sprite sheets.
enum PixelArt {
    static let ink = NSColor(srgbRed: 0.20, green: 0.17, blue: 0.22, alpha: 1)
    static let orange = NSColor(srgbRed: 0.94, green: 0.60, blue: 0.28, alpha: 1)
    static let shade = NSColor(srgbRed: 0.77, green: 0.38, blue: 0.20, alpha: 1)
    static let cream = NSColor(srgbRed: 1.0, green: 0.88, blue: 0.65, alpha: 1)
    static let pink = NSColor(srgbRed: 0.96, green: 0.56, blue: 0.56, alpha: 1)
    static let green = NSColor(srgbRed: 0.32, green: 0.56, blue: 0.43, alpha: 1)
    static func cat(_ action: CatAction, frame: Int, skin: Int = 1, fast: Bool = false) -> NSImage {
        CatSprites.image(skin: skin, action: action, frame: frame, fast: fast)
    }

    static func ball(in rect: NSRect) {
        NSGraphicsContext.current?.shouldAntialias = false
        let unit = rect.width / 12
        func b(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: NSColor) {
            color.setFill()
            NSRect(x: rect.minX + CGFloat(x) * unit, y: rect.minY + CGFloat(y) * unit,
                   width: CGFloat(w) * unit, height: CGFloat(h) * unit).fill()
        }
        b(3, 0, 6, 12, ink); b(1, 2, 10, 8, ink); b(0, 4, 12, 4, ink)
        b(3, 1, 6, 10, pink); b(2, 3, 8, 6, pink)
        b(3, 8, 4, 2, cream); b(6, 2, 3, 2, shade)
        b(5, 3, 1, 5, ink); b(6, 5, 4, 1, ink)
    }

    static func feather(at point: NSPoint) {
        NSGraphicsContext.current?.shouldAntialias = false
        green.setFill()
        NSRect(x: point.x - 6, y: point.y - 8, width: 10, height: 18).fill()
        NSRect(x: point.x - 10, y: point.y - 3, width: 18, height: 8).fill()
        cream.setFill()
        NSRect(x: point.x - 2, y: point.y - 8, width: 2, height: 19).fill()
        pink.setFill()
        NSRect(x: point.x + 4, y: point.y - 7, width: 4, height: 10).fill()
    }
}
