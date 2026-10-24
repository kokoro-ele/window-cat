import Foundation
import CoreGraphics

public struct WindowIdentity: Hashable {
    public let owner: Int32
    public let number: UInt32
    public init(owner: Int32, number: UInt32) { self.owner = owner; self.number = number }
}

public struct WindowGeometry {
    public let identity: WindowIdentity
    public let rect: CGRect
    public let layer: Int
    public let alpha: Double
    public init(identity: WindowIdentity, rect: CGRect, layer: Int = 0, alpha: Double = 1) {
        self.identity = identity; self.rect = rect; self.layer = layer; self.alpha = alpha
    }
}

public enum WindowSelection {
    /// Input is front-to-back from the window server. Identity is fixed at drop time.
    public static func target(at point: CGPoint, windows: [WindowGeometry], excluding: Set<WindowIdentity>) -> WindowGeometry? {
        windows.first {
            !excluding.contains($0.identity) && $0.layer == 0 && $0.alpha > 0 &&
            $0.rect.width > 80 && $0.rect.height > 60 && $0.rect.contains(point)
        }
    }

    public static func isExposed(_ area: CGRect, target: WindowIdentity, windows: [WindowGeometry], ownPID: Int32) -> Bool {
        for window in windows {
            if window.identity == target { return true }
            if window.identity.owner != ownPID && window.alpha > 0 && window.layer >= 0 &&
                // Dock's level-20 window can be a transparent full-screen surface.
                // Its bounding box must not hide every cat on the desktop.
                window.layer < 20 && !window.rect.intersection(area).isNull { return false }
        }
        return false
    }
}
