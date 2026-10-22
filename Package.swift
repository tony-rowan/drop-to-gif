// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DropToGif",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "GifKit"),
        .executableTarget(name: "DropToGif", dependencies: ["GifKit"]),
        .testTarget(name: "GifKitTests", dependencies: ["GifKit"])
    ]
)
