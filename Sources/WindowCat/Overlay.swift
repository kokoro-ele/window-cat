import AppKit
import CatCore

final class OverlayPanel: NSPanel {
    init(size: CGFloat, name: String) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        title = name
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenNone]
        animationBehavior = .none
        isMovable = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(anchor: CGPoint) {
        setFrameOrigin(NSPoint(x: (anchor.x - frame.width / 2).rounded(),
                               y: (anchor.y - frame.height / 2).rounded()))
        if !isVisible { orderFrontRegardless() }
    }
}

final class CatView: NSView {
    var skin = 1 { didSet { drawingKey = ""; needsDisplay = true } }
    var action: CatAction = .running
    var frameIndex = 0
    var angle: CGFloat = 0
    var facingForward = true
    var leap: CGFloat = 0
    var fast = false
    private var drawingKey = ""

    func update(_ world: CatWorld) {
        let fps: Double = world.action == .sleeping ? 0.8 : world.action == .idle ? 4 : 10
        let count = CatSprites.frameCount(world.action, fast: world.mode == .ball || world.mode == .wand)
        let index = Int(world.time * fps) % count
        let key = "\(skin)-\(world.mode)-\(world.action)-\(index)-\(world.facingForward)-\(Int(world.pose.angle * 100))-\(Int(world.leap))"
        guard key != drawingKey else { return }
        drawingKey = key
        action = world.action
        frameIndex = index
        angle = world.pose.angle
        facingForward = world.facingForward
        leap = world.leap
        fast = world.mode == .ball || world.mode == .wand
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.saveGState()
        context.setShouldAntialias(false)
        context.interpolationQuality = .none
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: angle)
        context.translateBy(x: 0, y: leap.rounded())
        if !facingForward { context.scaleBy(x: -1, y: 1) }
        PixelArt.cat(action, frame: frameIndex, skin: skin, fast: fast).draw(in: NSRect(x: -CatSprites.drawSize.width / 2, y: 0, width: CatSprites.drawSize.width, height: CatSprites.drawSize.height))
        if action == .sleeping {
            let shift: CGFloat = frameIndex == 0 ? 0 : 3
            PixelArt.green.setFill()
            // Pixel Z; no font rasterization inside the sprite.
            for (x, y, w, h) in [(0, 8, 8, 2), (6, 6, 2, 2), (4, 4, 2, 2), (2, 2, 2, 2), (0, 0, 8, 2)] {
                NSRect(x: 19 + CGFloat(x), y: 29 + CGFloat(y) + shift,
                       width: CGFloat(w), height: CGFloat(h)).fill()
            }
        }
        context.restoreGState()
    }
}

final class ToyView: NSView {
    var mode: CatMode = .ball { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.setShouldAntialias(false)
        if mode == .ball {
            PixelArt.ball(in: NSRect(x: bounds.midX - 7, y: bounds.midY - 7, width: 14, height: 14))
        } else {
            let p = CGPoint(x: bounds.midX, y: bounds.midY)
            PixelArt.ink.setStroke()
            let stick = NSBezierPath()
            stick.lineWidth = 3
            stick.move(to: CGPoint(x: p.x + 10, y: p.y + 35))
            stick.line(to: CGPoint(x: p.x + 29, y: p.y + 53))
            stick.stroke()
            let string = NSBezierPath()
            string.lineWidth = 1
            string.move(to: CGPoint(x: p.x + 10, y: p.y + 35))
            string.line(to: CGPoint(x: p.x + 5, y: p.y + 19))
            string.line(to: CGPoint(x: p.x, y: p.y + 8))
            string.stroke()
            PixelArt.feather(at: p)
        }
    }
}
