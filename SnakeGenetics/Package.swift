// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SnakeGenetics",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SnakeGenetics", targets: ["SnakeGenetics"])
    ],
    targets: [
        .target(name: "SnakeGenetics"),
        .testTarget(name: "SnakeGeneticsTests", dependencies: ["SnakeGenetics"])
    ]
)
