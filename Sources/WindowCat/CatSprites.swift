import AppKit
import CatCore

/// Elthen's original 32×32 cells. Each row is one animation; preserve its baseline.
enum CatSprites {
    static let drawSize = NSSize(width: 60, height: 54)
    private static var cache: [String: [NSImage]] = [:]
    static var resourceRoot: URL {
        if Bundle.main.bundleURL.pathExtension == "app" { return Bundle.main.resourceURL! }
        return Bundle.module.resourceURL!.appendingPathComponent("Resources")
    }
    private static let sheet: CGImage = {
        let url = resourceRoot.appendingPathComponent("Elthen/Cat.png")
        guard let data = try? Data(contentsOf: url), let bitmap = NSBitmapImageRep(data: data),
              let image = bitmap.cgImage, image.width == 256, image.height == 320 else {
            preconditionFailure("Missing or invalid Elthen cat sheet")
        }
        return image
    }()
    static let menuIcon: NSImage = {
        let crop = sheet.cropping(to: CGRect(x: 9, y: 20, width: 12, height: 12))!
        return NSImage(cgImage: crop, size: NSSize(width: 18, height: 18))
    }()
    static func animation(_ action: CatAction, fast: Bool) -> String {
        switch action {
        case .running: return fast ? "Run" : "Walk"
        case .idle: return "Idle"
        case .sleeping: return "Sleep"
        case .pouncing: return "Paw"
        }
    }
    static func frameCount(_ action: CatAction, fast: Bool) -> Int {
        load(skin: 1, animation: animation(action, fast: fast)).count
    }
    static func image(skin: Int, action: CatAction, frame: Int, fast: Bool = false) -> NSImage {
        let frames = load(skin: 1, animation: animation(action, fast: fast))
        return frames[max(0, frame) % frames.count]
    }
    static func load(skin: Int, animation: String) -> [NSImage] {
        if let frames = cache[animation] { return frames }
        let row: Int, count: Int
        switch animation {
        case "Idle": (row, count) = (0, 4)
        case "Idle2": (row, count) = (1, 4)
        case "Groom": (row, count) = (2, 4)
        case "Groom2": (row, count) = (3, 4)
        case "Walk": (row, count) = (4, 8)
        case "Run": (row, count) = (5, 8)
        case "Sleep": (row, count) = (6, 4)
        case "Paw": (row, count) = (7, 6)
        case "Jump": (row, count) = (8, 7)
        case "Scared": (row, count) = (9, 8)
        default: preconditionFailure("Unknown animation: \(animation)")
        }
        let frames = (0..<count).map { index -> NSImage in
            // Uniform crop includes every pose, preserving all original motion offsets.
            let crop = sheet.cropping(to: CGRect(x: index * 32 + 6, y: row * 32 + 14, width: 20, height: 18))!
            return NSImage(cgImage: crop, size: drawSize)
        }
        cache[animation] = frames
        return frames
    }
}
