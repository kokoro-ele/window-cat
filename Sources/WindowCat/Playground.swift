import AppKit
import CatCore

// Only instantiated by the explicit --diagnostics test command.
final class DiagnosticWindow: NSWindow {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 580, height: 340),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        minSize = NSSize(width: 420, height: 270)
        appearance = NSAppearance(named: .aqua)
        center()
        updateLanguage()
    }
    func updateLanguage() {
        title = tr(.demoTitle)
        backgroundColor = NSColor(srgbRed: 0.97, green: 0.96, blue: 0.92, alpha: 1)
        let root = NSView()
        let title = NSTextField(labelWithString: tr(.demoTitle))
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        let body = NSTextField(wrappingLabelWithString: tr(.demoBody))
        body.font = .systemFont(ofSize: 13); body.textColor = .secondaryLabelColor
        body.alignment = .center
        for view in [title, body] { view.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(view) }
        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: 33),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            body.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            body.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -60)
        ])
        contentView = root
    }
}

final class DropOutline: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 12, yRadius: 12)
        PixelArt.green.withAlphaComponent(0.07).setFill(); shape.fill()
        PixelArt.green.setStroke(); shape.lineWidth = 3; shape.stroke()
        let text = tr(.dropReady) as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white]
        let size = text.size(withAttributes: attrs)
        let box = NSRect(x: bounds.midX - size.width / 2 - 14, y: bounds.maxY - 50, width: size.width + 28, height: 30)
        PixelArt.green.setFill(); NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8).fill()
        text.draw(at: NSPoint(x: box.minX + 14, y: box.minY + 7), withAttributes: attrs)
    }
}
