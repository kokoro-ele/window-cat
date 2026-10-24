import AppKit

/// A press stays a click until it travels four points; the menu never consumes a drag.
final class StatusDragView: NSView {
    var skin = 1 { didSet { needsDisplay = true } }
    var onBegin: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onDrop: ((CGPoint) -> Void)?
    var onClick: (() -> Void)?
    private var origin = CGPoint.zero
    private var dragging = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
    override func mouseDown(with event: NSEvent) {
        origin = NSEvent.mouseLocation; dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        if !dragging && hypot(point.x - origin.x, point.y - origin.y) >= 4 {
            dragging = true; onBegin?(point)
        }
        if dragging { onDrag?(point) }
    }
    override func mouseUp(with event: NSEvent) {
        if dragging { onDrop?(NSEvent.mouseLocation) }
        else { onClick?() }
        dragging = false
    }
    override func rightMouseDown(with event: NSEvent) { onClick?() }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none
        CatSprites.menuIcon.draw(in: NSRect(x: bounds.midX - 9, y: bounds.midY - 9, width: 18, height: 18))
    }
}
