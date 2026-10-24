import XCTest
import CoreGraphics
@testable import CatCore

final class WindowSelectionTests: XCTestCase {
    let a = WindowIdentity(owner: 11, number: 100)
    let b = WindowIdentity(owner: 11, number: 200)
    let sidebar = WindowIdentity(owner: 99, number: 300)
    let rect = CGRect(x: 100, y: 200, width: 600, height: 400)

    func testDropChoosesTopmostWindowEvenWithinTheSameApp() {
        let windows = [WindowGeometry(identity: b, rect: rect), WindowGeometry(identity: a, rect: rect)]
        XCTAssertEqual(WindowSelection.target(at: CGPoint(x: 200, y: 300), windows: windows, excluding: [])?.identity, b)
    }
    func testFloatingDragPreviewCannotBecomeItsOwnTarget() {
        let windows = [WindowGeometry(identity: sidebar, rect: rect, layer: 3), WindowGeometry(identity: a, rect: rect)]
        XCTAssertEqual(WindowSelection.target(at: CGPoint(x: 200, y: 300), windows: windows, excluding: [])?.identity, a)
    }
    func testDesktopAndTransparentWindowCannotReceiveCats() {
        let windows = [WindowGeometry(identity: a, rect: rect, alpha: 0)]
        XCTAssertNil(WindowSelection.target(at: CGPoint(x: 200, y: 300), windows: windows, excluding: []))
        XCTAssertNil(WindowSelection.target(at: CGPoint(x: -1000, y: -1000), windows: windows, excluding: []))
    }
    func testExclusionsAreExactWindowIdentities() {
        let windows = [WindowGeometry(identity: b, rect: rect), WindowGeometry(identity: a, rect: rect)]
        XCTAssertEqual(WindowSelection.target(at: CGPoint(x: 200, y: 300), windows: windows, excluding: [b])?.identity, a)
    }
    func testFocusOrderDoesNotChangeAnExistingBinding() {
        let pinned = a
        let windows = [WindowGeometry(identity: b, rect: rect.offsetBy(dx: 650, dy: 0)), WindowGeometry(identity: a, rect: rect)]
        XCTAssertTrue(WindowSelection.isExposed(CGRect(x: 200, y: 300, width: 30, height: 30), target: pinned, windows: windows, ownPID: 99))
        XCTAssertEqual(pinned, a)
    }
    func testCoveredPartOfBoundWindowHidesCat() {
        let windows = [WindowGeometry(identity: b, rect: rect), WindowGeometry(identity: a, rect: rect)]
        XCTAssertFalse(WindowSelection.isExposed(CGRect(x: 200, y: 300, width: 30, height: 30), target: a, windows: windows, ownPID: 99))
    }
    func testOwnOverlayDoesNotOccludeItsCat() {
        let windows = [WindowGeometry(identity: sidebar, rect: rect, layer: 3), WindowGeometry(identity: a, rect: rect)]
        XCTAssertTrue(WindowSelection.isExposed(CGRect(x: 200, y: 300, width: 30, height: 30), target: a, windows: windows, ownPID: 99))
    }
    func testMissingWindowIsNotVisible() {
        XCTAssertFalse(WindowSelection.isExposed(rect, target: a, windows: [], ownPID: 99))
    }
    func testTransparentDesktopDockSurfaceDoesNotHideCat() {
        let dock = WindowIdentity(owner: 77, number: 23)
        let windows = [WindowGeometry(identity: dock, rect: rect, layer: 20), WindowGeometry(identity: a, rect: rect)]
        XCTAssertTrue(WindowSelection.isExposed(rect, target: a, windows: windows, ownPID: 99))
    }
    func testOrdinaryFloatingPanelStillOccludesCat() {
        let panel = WindowIdentity(owner: 77, number: 24)
        let windows = [WindowGeometry(identity: panel, rect: rect, layer: 3), WindowGeometry(identity: a, rect: rect)]
        XCTAssertFalse(WindowSelection.isExposed(rect, target: a, windows: windows, ownPID: 99))
    }
}

final class LocalizationTests: XCTestCase {
    func testEveryKeyHasAllThreeTranslations() {
        for key in TextKey.allCases {
            XCTAssertEqual(LocalizationCatalog.entries[key]?.count, 3, key.rawValue)
            for language in AppLanguage.allCases {
                XCTAssertFalse(LocalizationCatalog.text(key, language: language).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    func testSystemLanguageMatchingAndFallback() {
        XCTAssertEqual(AppLanguage.preferred(from: ["ja-JP", "en-US"]), .japanese)
        XCTAssertEqual(AppLanguage.preferred(from: ["en-GB"]), .english)
        XCTAssertEqual(AppLanguage.preferred(from: ["zh-TW"]), .chinese)
        XCTAssertEqual(AppLanguage.preferred(from: ["de-DE"]), .english)
    }
    func testEnglishUIHasNoUntranslatedChineseCopy() {
        for key in TextKey.allCases {
            let english = LocalizationCatalog.text(key, language: .english)
            XCTAssertFalse(english.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }, key.rawValue)
        }
    }
}
