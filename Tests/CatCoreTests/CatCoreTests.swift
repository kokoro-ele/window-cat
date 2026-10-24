import XCTest
import CoreGraphics
@testable import CatCore

final class WindowPathTests: XCTestCase {
    let rect = CGRect(x: 100, y: 200, width: 600, height: 400)

    func testPathClosesWithoutJumpAndAcceptsNegativeDistances() {
        let path = WindowPath(rect: rect)
        let start = path.pose(at: 0).point
        let end = path.pose(at: path.length).point
        XCTAssertEqual(start.x, end.x, accuracy: 0.0001)
        XCTAssertEqual(start.y, end.y, accuracy: 0.0001)
        let before = path.pose(at: -0.01).point
        XCTAssertLessThan(hypot(start.x - before.x, start.y - before.y), 0.011)
        XCTAssertEqual(path.pose(at: -120).point, path.pose(at: path.length - 120).point)
    }

    func testEveryEdgeFacesOutward() {
        let path = WindowPath(rect: rect)
        for point in [CGPoint(x: 400, y: 600), CGPoint(x: 700, y: 400),
                      CGPoint(x: 400, y: 200), CGPoint(x: 100, y: 400)] {
            let pose = path.pose(at: path.nearestDistance(to: point))
            XCTAssertEqual(pose.point.x, point.x, accuracy: 0.001)
            XCTAssertEqual(pose.point.y, point.y, accuracy: 0.001)
            let outward = CGPoint(x: -sin(pose.angle), y: cos(pose.angle))
            let centerDelta = CGPoint(x: point.x - rect.midX, y: point.y - rect.midY)
            XCTAssertGreaterThan(outward.x * centerDelta.x + outward.y * centerDelta.y, 0)
        }
    }

    func testProjectionRoundTripsAcrossAllCorners() {
        let path = WindowPath(rect: rect)
        for i in 0..<1000 {
            let distance = CGFloat(i) / 1000 * path.length
            let point = path.pose(at: distance).point
            let projected = path.nearestDistance(to: point)
            XCTAssertEqual(path.shortestDelta(from: distance, to: projected), 0, accuracy: 0.0001)
            XCTAssertTrue(rect.insetBy(dx: -0.001, dy: -0.001).contains(point))
        }
    }

    func testCornersHaveContinuousPositionAndTangent() {
        let path = WindowPath(rect: rect)
        let top = rect.width - path.radius * 2
        let corner = path.radius * .pi / 2
        for junction in [top, top + corner, top + corner + rect.height - 2 * path.radius] {
            let a = path.pose(at: junction - 0.0001)
            let b = path.pose(at: junction + 0.0001)
            XCTAssertLessThan(hypot(a.point.x - b.point.x, a.point.y - b.point.y), 0.001)
            XCTAssertLessThan(abs(a.angle - b.angle), 0.001)
        }
    }

    func testShortestRouteCrossesTheStartSeam() {
        let path = WindowPath(rect: rect)
        XCTAssertEqual(path.shortestDelta(from: 5, to: path.length - 5), -10, accuracy: 0.001)
        XCTAssertEqual(path.shortestDelta(from: path.length - 5, to: 5), 10, accuracy: 0.001)
    }

    func testAccessibilityConversionSupportsDisplaysAboveAndLeftOfPrimary() {
        let result = DesktopCoordinates.appKitRect(position: CGPoint(x: -1200, y: -800),
                                                   size: CGSize(width: 900, height: 600), primaryTop: 900)
        XCTAssertEqual(result, CGRect(x: -1200, y: 1100, width: 900, height: 600))
    }

    func testWindowAtScreenBoundaryLeavesRoomForSprite() {
        let screen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let track = DesktopCoordinates.trackRect(window: screen, visibleScreen: screen)
        XCTAssertEqual(track, screen.insetBy(dx: 44, dy: 44))
        XCTAssertEqual(DesktopCoordinates.trackRect(window: CGRect(x: 5000, y: 0, width: 200, height: 100),
                                                    visibleScreen: screen), .zero)
    }
}

final class CatWorldTests: XCTestCase {
    func makeWorld() -> CatWorld {
        CatWorld(rect: CGRect(x: 100, y: 100, width: 600, height: 400))
    }

    func advance(_ world: inout CatWorld, seconds: Double, pointer: CGPoint? = nil) {
        for _ in 0..<Int(seconds * 30) { world.tick(1.0 / 30, pointer: pointer) }
    }

    func testMovementUsesElapsedTimeInsteadOfFrameCount() {
        var a = makeWorld(), b = makeWorld()
        for _ in 0..<300 { a.tick(1.0 / 30) }
        for _ in 0..<600 { b.tick(1.0 / 60) }
        XCTAssertEqual(a.distance, b.distance, accuracy: 0.01)
    }

    func testLongStallDoesNotTeleportCat() {
        var world = makeWorld()
        let start = world.distance
        world.tick(100)
        XCTAssertLessThanOrEqual(abs(world.distance - start), world.speed * 0.1 + 0.001)
    }

    func testManualNapReachesTopAndStaysAsleepUntilWoken() {
        var world = makeWorld()
        advance(&world, seconds: 10)
        world.choose(.nap)
        advance(&world, seconds: 30)
        XCTAssertEqual(world.action, .sleeping)
        XCTAssertEqual(world.pose.point.y, world.path.rect.maxY, accuracy: 0.001)
        advance(&world, seconds: 40)
        XCTAssertEqual(world.action, .sleeping)
        world.choose(.ball)
        XCTAssertEqual(world.action, .running)
        XCTAssertEqual(world.mode, .ball)
    }

    func testAutomaticNapWakesWithOneHertzSleepingUpdates() {
        var world = makeWorld()
        advance(&world, seconds: 75)
        XCTAssertEqual(world.mode, .nap)
        XCTAssertEqual(world.action, .sleeping)
        for _ in 0..<19 { world.tick(1) }
        XCTAssertEqual(world.mode, .roam)
    }

    func testDisableAutomaticNaps() {
        var world = makeWorld()
        world.automaticNaps = false
        advance(&world, seconds: 130)
        XCTAssertEqual(world.mode, .roam)
    }

    func testSleepingCatStaysOnLedgeWhenWindowChangesSize() {
        var world = makeWorld()
        world.choose(.nap)
        advance(&world, seconds: 5)
        XCTAssertEqual(world.action, .sleeping)
        world.updateRect(CGRect(x: -800, y: 500, width: 300, height: 250))
        XCTAssertEqual(world.pose.point.x, -650, accuracy: 0.001)
        XCTAssertEqual(world.pose.point.y, 750, accuracy: 0.001)
    }

    func testBallStaysOnTopLedgeAndCatActuallyKicksIt() {
        var world = makeWorld()
        world.choose(.ball)
        var sawKick = false
        for _ in 0..<3600 {
            world.tick(1.0 / 30)
            XCTAssertTrue((0...1).contains(world.ballFraction))
            XCTAssertGreaterThan(world.ballPoint.y, world.path.rect.maxY)
            XCTAssertGreaterThan(world.ballPoint.x, world.path.rect.minX)
            XCTAssertLessThan(world.ballPoint.x, world.path.rect.maxX)
            sawKick = sawKick || world.action == .pouncing
        }
        XCTAssertTrue(sawKick)
    }

    func testWandUsesNearestEdgeAndPouncesWhenClose() {
        var world = makeWorld()
        world.choose(.wand)
        let point = CGPoint(x: 650, y: 510)
        var sawPounce = false
        for _ in 0..<900 {
            world.tick(1.0 / 30, pointer: point)
            sawPounce = sawPounce || world.action == .pouncing
        }
        XCTAssertEqual(world.pose.point.x, 650, accuracy: 0.01)
        XCTAssertEqual(world.pose.point.y, 500, accuracy: 0.01)
        XCTAssertTrue(sawPounce)
    }

    func testMissingPointerDoesNotSendCatToOrigin() {
        var world = makeWorld()
        world.choose(.wand)
        let start = world.pose.point
        world.tick(0.03)
        XCTAssertEqual(world.action, .idle)
        XCTAssertEqual(world.pose.point, start)
    }
}
