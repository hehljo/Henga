// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SynologyMount",
    defaultLocalization: "de",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SynologyMountCore",
            targets: ["SynologyMountCore"]
        ),
        .executable(
            name: "SynologyMountMac",
            targets: ["SynologyMountMac"]
        ),
        .executable(
            name: "syno-mount-cli",
            targets: ["SynologyMountCLI"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SynologyMountCore",
            dependencies: [],
            path: "Sources/SynologyMountCore"
        ),
        .executableTarget(
            name: "SynologyMountMac",
            dependencies: ["SynologyMountCore"],
            path: "Sources/SynologyMountMac",
            exclude: ["App.entitlements", "Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .process("Localizable.xcstrings")
            ]
        ),
        .executableTarget(
            name: "SynologyMountCLI",
            dependencies: ["SynologyMountCore"],
            path: "Sources/SynologyMountCLI"
        ),
        .testTarget(
            name: "SynologyMountTests",
            dependencies: ["SynologyMountCore"],
            path: "Tests/SynologyMountTests"
        )
    ]
)
