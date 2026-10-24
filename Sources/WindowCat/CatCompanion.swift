import AppKit
import CatCore

final class CatCompanion {
    let target: WindowTarget
    var skin: Int { didSet { view.skin = skin } }
    var world: CatWorld
    var rect: CGRect?
    let panel = OverlayPanel(size: 192, name: "windowcat")
    let toyPanel = OverlayPanel(size: 128, name: "Toy")
    let view = CatView()
    let toyView = ToyView()

    init(target: WindowTarget, skin: Int, speed: CGFloat, automaticNaps: Bool) {
        self.target = target; self.skin = skin
        world = CatWorld(rect: target.initialRect)
        world.speed = speed; world.automaticNaps = automaticNaps
        view.skin = skin
        panel.contentView = view; toyPanel.contentView = toyView
        view.setAccessibilityElement(false); toyView.setAccessibilityElement(false)
    }

    func setRect(_ rect: CGRect?) {
        guard let rect, let screen = NSScreen.screens.max(by: {
            area($0.visibleFrame.intersection(rect)) < area($1.visibleFrame.intersection(rect))
        }) else { self.rect = nil; hide(); return }
        let track = DesktopCoordinates.trackRect(window: rect, visibleScreen: screen.visibleFrame, margin: 58)
        guard track.width >= 60, track.height >= 60 else { self.rect = nil; hide(); return }
        self.rect = track
        world.updateRect(track)
    }

    func draw(tracker: WindowTracker, pointer: CGPoint) {
        guard rect != nil else { hide(); return }
        let pose = world.pose
        let center = CGPoint(x: pose.point.x - sin(pose.angle) * 24, y: pose.point.y + cos(pose.angle) * 24)
        let area = CGRect(x: center.x - 28, y: center.y - 20, width: 56, height: 40)
        if tracker.exposed(area, target: target.identity) {
            view.update(world); panel.place(anchor: pose.point)
        } else { panel.orderOut(nil) }
        if world.mode == .ball || world.mode == .wand {
            let point = world.mode == .ball ? world.ballPoint : pointer
            if tracker.exposed(CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10), target: target.identity) {
                if toyView.mode != world.mode { toyView.mode = world.mode }
                toyPanel.place(anchor: point)
            } else { toyPanel.orderOut(nil) }
        } else { toyPanel.orderOut(nil) }
    }
    func hide() { panel.orderOut(nil); toyPanel.orderOut(nil) }
    private func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
    deinit { hide() }
}
