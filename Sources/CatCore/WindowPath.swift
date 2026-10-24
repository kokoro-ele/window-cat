import Foundation
import CoreGraphics

public struct PathPose {
    public var point: CGPoint
    /// Clockwise tangent angle. The sprite's feet sit on the path.
    public var angle: CGFloat
}

public enum DesktopCoordinates {
    /// Accessibility uses a top-left origin on the primary display; AppKit uses bottom-left.
    public static func appKitRect(position: CGPoint, size: CGSize, primaryTop: CGFloat) -> CGRect {
        CGRect(x: position.x, y: primaryTop - position.y - size.height,
               width: size.width, height: size.height)
    }

    /// Leave room for the cat when a window touches a screen edge.
    public static func trackRect(window: CGRect, visibleScreen: CGRect, margin: CGFloat = 44) -> CGRect {
        let safe = visibleScreen.insetBy(dx: margin, dy: margin)
        let expanded = window.insetBy(dx: -2, dy: -2)
        let clipped = expanded.intersection(safe)
        return clipped.isNull || clipped.width < 60 || clipped.height < 60 ? .zero : clipped
    }
}

public struct WindowPath {
    public let rect: CGRect
    public let radius: CGFloat
    public let length: CGFloat
    private let segments: [Segment]

    private enum Segment {
        case line(CGPoint, CGPoint)
        case arc(CGPoint, CGFloat, CGFloat)

        var length: CGFloat {
            switch self {
            case let .line(a, b): return hypot(b.x - a.x, b.y - a.y)
            case let .arc(_, r, _): return r * .pi / 2
            }
        }

        func pose(_ t: CGFloat) -> PathPose {
            switch self {
            case let .line(a, b):
                return PathPose(point: CGPoint(x: a.x + (b.x - a.x) * t,
                                               y: a.y + (b.y - a.y) * t),
                                angle: atan2(b.y - a.y, b.x - a.x))
            case let .arc(c, r, start):
                let angle = start - t * .pi / 2
                return PathPose(point: CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r),
                                angle: angle - .pi / 2)
            }
        }

        func nearestParameter(to point: CGPoint) -> CGFloat {
            switch self {
            case let .line(a, b):
                let dx = b.x - a.x, dy = b.y - a.y
                let squared = dx * dx + dy * dy
                guard squared > 0 else { return 0 }
                return min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / squared))
            case let .arc(c, _, start):
                let angle = atan2(point.y - c.y, point.x - c.x)
                let delta = WindowPath.wrap(start - angle, period: .pi * 2)
                if delta <= .pi / 2 { return delta / (.pi / 2) }
                let a = pose(0).point, b = pose(1).point
                return hypot(point.x - a.x, point.y - a.y) <= hypot(point.x - b.x, point.y - b.y) ? 0 : 1
            }
        }
    }

    public init(rect: CGRect, radius: CGFloat = 14) {
        let rect = CGRect(x: rect.minX, y: rect.minY, width: max(2, rect.width), height: max(2, rect.height))
        self.rect = rect
        let r = max(0.1, min(radius, min(rect.width, rect.height) / 4))
        self.radius = r
        let l = rect.minX, b = rect.minY, t = rect.maxY, right = rect.maxX
        segments = [
            .line(CGPoint(x: l + r, y: t), CGPoint(x: right - r, y: t)),
            .arc(CGPoint(x: right - r, y: t - r), r, .pi / 2),
            .line(CGPoint(x: right, y: t - r), CGPoint(x: right, y: b + r)),
            .arc(CGPoint(x: right - r, y: b + r), r, 0),
            .line(CGPoint(x: right - r, y: b), CGPoint(x: l + r, y: b)),
            .arc(CGPoint(x: l + r, y: b + r), r, -.pi / 2),
            .line(CGPoint(x: l, y: b + r), CGPoint(x: l, y: t - r)),
            .arc(CGPoint(x: l + r, y: t - r), r, .pi)
        ]
        length = segments.reduce(0) { $0 + $1.length }
    }

    public static func wrap(_ value: CGFloat, period: CGFloat) -> CGFloat {
        guard period > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: period)
        return remainder < 0 ? remainder + period : remainder
    }

    public func pose(at distance: CGFloat) -> PathPose {
        var remaining = Self.wrap(distance, period: length)
        for segment in segments {
            if remaining <= segment.length { return segment.pose(remaining / segment.length) }
            remaining -= segment.length
        }
        return segments[0].pose(0)
    }

    public func nearestDistance(to point: CGPoint) -> CGFloat {
        var offset: CGFloat = 0, bestDistance: CGFloat = 0, bestSquared = CGFloat.infinity
        for segment in segments {
            let t = segment.nearestParameter(to: point)
            let p = segment.pose(t).point
            let squared = pow(point.x - p.x, 2) + pow(point.y - p.y, 2)
            if squared < bestSquared {
                bestSquared = squared
                bestDistance = offset + segment.length * t
            }
            offset += segment.length
        }
        return Self.wrap(bestDistance, period: length)
    }

    public func shortestDelta(from: CGFloat, to: CGFloat) -> CGFloat {
        Self.wrap(to - from + length / 2, period: length) - length / 2
    }

    public var topCenter: CGFloat { (rect.width - radius * 2) / 2 }
}
