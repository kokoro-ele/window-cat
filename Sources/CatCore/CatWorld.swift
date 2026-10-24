import Foundation
import CoreGraphics

public enum CatMode: String { case roam, nap, ball, wand }
public enum CatAction: String { case running, idle, sleeping, pouncing }

/// A small deterministic simulation; it knows nothing about windows, timers, or permissions.
public struct CatWorld {
    public private(set) var path: WindowPath
    public private(set) var mode: CatMode = .roam
    public private(set) var action: CatAction = .running
    public private(set) var distance: CGFloat = 0
    public private(set) var facingForward = true
    public private(set) var time: TimeInterval = 0
    public private(set) var ballFraction: CGFloat = 0.65
    public private(set) var ballVelocity: CGFloat = 70
    public private(set) var leap: CGFloat = 0
    public var speed: CGFloat = 68
    public var automaticNaps = true
    private var roamTime: TimeInterval = 0
    private var sleepTime: TimeInterval = 0
    private var kickCooldown: TimeInterval = 0
    private var leapTime: TimeInterval = 0
    private var automaticNap = false

    public init(rect: CGRect) {
        path = WindowPath(rect: rect)
        distance = path.topCenter * 0.6
    }

    public mutating func updateRect(_ rect: CGRect) {
        guard rect != path.rect else { return }
        let fraction = distance / path.length
        path = WindowPath(rect: rect)
        distance = fraction * path.length
        // Preserve a sleeping cat's place on its ledge, including after a resize.
        if action == .sleeping { distance = path.topCenter }
    }

    public mutating func choose(_ mode: CatMode) {
        self.mode = mode
        automaticNap = false
        sleepTime = 0
        roamTime = 0
        leapTime = 0
        leap = 0
        action = .running
        if mode == .ball { ballFraction = 0.65; ballVelocity = 70; kickCooldown = 0 }
    }

    public var pose: PathPose { path.pose(at: distance) }

    public var ballPoint: CGPoint {
        let inset = min(35, path.rect.width / 4)
        return CGPoint(x: path.rect.minX + inset + ballFraction * (path.rect.width - inset * 2),
                       y: path.rect.maxY + 7 + abs(sin(time * 8)) * min(5, abs(ballVelocity) / 22))
    }

    public var description: String {
        switch mode {
        case .roam: return action == .idle ? "看看风景，甩甩尾巴" : "沿着窗边散步中"
        case .nap: return action == .sleeping ? "嘘，小猫睡着了…" : "找个舒服的位置打盹"
        case .ball: return "追上小球，再拨一下"
        case .wand: return "移动鼠标，带着小猫跑"
        }
    }

    public mutating func tick(_ elapsed: TimeInterval, pointer: CGPoint? = nil) {
        // Avoid giant jumps after sleep, a stopped debugger, or a blocked main thread.
        let dt = min(action == .sleeping ? 1.2 : 0.1, max(0, elapsed))
        time += dt
        kickCooldown = max(0, kickCooldown - dt)
        if leapTime > 0 {
            leapTime = max(0, leapTime - dt)
            leap = sin(CGFloat(1 - leapTime / 0.5) * .pi) * 18
        } else { leap = 0 }

        switch mode {
        case .roam:
            roamTime += dt
            if automaticNaps && roamTime >= 55 {
                mode = .nap
                automaticNap = true
                sleepTime = 0
                return
            }
            let lookingAround = roamTime.truncatingRemainder(dividingBy: 17) > 14.5
            action = lookingAround ? .idle : .running
            if !lookingAround {
                facingForward = true
                distance = WindowPath.wrap(distance + speed * CGFloat(dt), period: path.length)
            }
        case .nap:
            if move(toward: path.topCenter, dt: dt, pace: speed) {
                action = .sleeping
                sleepTime += dt
                if automaticNap && sleepTime >= 18 { choose(.roam) }
            }
        case .ball:
            let width = max(1, path.rect.width - min(35, path.rect.width / 4) * 2)
            ballFraction += ballVelocity * CGFloat(dt) / width
            if ballFraction < 0 { ballFraction = 0; ballVelocity = abs(ballVelocity) * 0.8 }
            if ballFraction > 1 { ballFraction = 1; ballVelocity = -abs(ballVelocity) * 0.8 }
            ballVelocity *= exp(-0.6 * CGFloat(dt))
            let target = path.nearestDistance(to: ballPoint)
            _ = move(toward: target, dt: dt, pace: speed * 1.55)
            if abs(path.shortestDelta(from: distance, to: target)) < 24 && kickCooldown == 0 {
                ballVelocity = ballFraction > 0.5 ? -150 : 150
                facingForward = ballVelocity > 0
                kickCooldown = 0.65
                leapTime = 0.5
            }
            if leapTime > 0 { action = .pouncing }
        case .wand:
            guard let pointer else { action = .idle; return }
            let target = path.nearestDistance(to: pointer)
            _ = move(toward: target, dt: dt, pace: speed * 1.8)
            let p = pose.point
            if hypot(p.x - pointer.x, p.y - pointer.y) < 85 && kickCooldown == 0 {
                leapTime = 0.5
                kickCooldown = 1.1
            }
            if leapTime > 0 { action = .pouncing }
        }
    }

    @discardableResult
    private mutating func move(toward target: CGFloat, dt: TimeInterval, pace: CGFloat) -> Bool {
        let delta = path.shortestDelta(from: distance, to: target)
        if abs(delta) < 1.5 {
            distance = WindowPath.wrap(target, period: path.length)
            action = .idle
            return true
        }
        facingForward = delta > 0
        action = .running
        distance = WindowPath.wrap(distance + (delta > 0 ? 1 : -1) * min(abs(delta), pace * CGFloat(dt)),
                                   period: path.length)
        return false
    }
}
