// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WindowCat",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WindowCat", targets: ["WindowCat"])],
    targets: [
        .target(name: "CatCore"),
        .executableTarget(name: "WindowCat", dependencies: ["CatCore"], resources: [.copy("Resources")]),
        .testTarget(name: "CatCoreTests", dependencies: ["CatCore"])
    ]
)
