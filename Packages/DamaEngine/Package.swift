// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DamaEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DamaEngine", targets: ["DamaEngine"])
    ],
    targets: [
        .target(name: "DamaEngine"),
        .testTarget(name: "DamaEngineTests", dependencies: ["DamaEngine"])
    ]
)
