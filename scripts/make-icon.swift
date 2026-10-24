import AppKit

// Build a native macOS icon from the same licensed sprite used in the app.
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let bitmap = NSBitmapImageRep(data: try Data(contentsOf: source))!
let cat = bitmap.cgImage!.cropping(to: CGRect(x: 9, y: 20, width: 12, height: 12))!
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let s = CGFloat(size)
        context.setFillColor(CGColor(red: 0.94, green: 0.90, blue: 0.81, alpha: 1))
        context.addPath(CGPath(roundedRect: CGRect(x: s * 0.07, y: s * 0.07, width: s * 0.86, height: s * 0.86), cornerWidth: s * 0.19, cornerHeight: s * 0.19, transform: nil))
        context.fillPath()
        context.interpolationQuality = .none
        let pixelScale = max(1, floor(s * 0.66 / 12))
        let width = pixelScale * 12
        context.draw(cat, in: CGRect(x: floor((s - width) / 2), y: floor((s - width) / 2), width: width, height: width))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
