// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MurdlCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MurdlCore", targets: ["MurdlCore"]),
        /// C ABI for non-Swift front ends: MurdlBridge.dll on Windows, libMurdlBridge.dylib on macOS.
        .library(name: "MurdlBridge", type: .dynamic, targets: ["MurdlBridge"]),
    ],
    targets: [
        .target(
            name: "MurdlCore",
            resources: [.copy("Resources/Dictionaries")]
        ),
        .target(
            name: "MurdlBridge",
            dependencies: ["MurdlCore"],
            exclude: ["murdl.h"]
        ),
        .testTarget(
            name: "MurdlCoreTests",
            dependencies: ["MurdlCore"]
        ),
        .testTarget(
            name: "MurdlBridgeTests",
            dependencies: ["MurdlBridge"]
        ),
    ]
)
