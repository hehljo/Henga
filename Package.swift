// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Henga",
    defaultLocalization: "de",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HengaCore",
            targets: ["HengaCore"]
        ),
        .executable(
            name: "HengaMac",
            targets: ["HengaMac"]
        ),
        .executable(
            name: "henga-cli",
            targets: ["HengaCLI"]
        )
    ],
    targets: [
        .target(
            name: "HengaCore",
            dependencies: [],
            path: "Sources/HengaCore"
        ),
        .executableTarget(
            name: "HengaMac",
            dependencies: ["HengaCore"],
            path: "Sources/HengaMac",
            exclude: [
                "Info.plist",
                "App.entitlements"
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Localizable.xcstrings")
            ]
        ),
        .executableTarget(
            name: "HengaCLI",
            dependencies: ["HengaCore"],
            path: "Sources/HengaCLI"
        ),
        .testTarget(
            name: "HengaTests",
            dependencies: ["HengaCore"],
            path: "Tests/HengaTests"
        )
    ]
)
