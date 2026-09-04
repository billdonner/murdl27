// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MurdlCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MurdlCore", targets: ["MurdlCore"]),
    ],
    targets: [
        .target(
            name: "MurdlCore",
            resources: [.copy("Resources/Dictionaries")]
        ),
        .testTarget(
            name: "MurdlCoreTests",
            dependencies: ["MurdlCore"]
        ),
    ]
)
