// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wachmacher",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Automatic updates outside the App Store.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1"),
    ],
    targets: [
        // Pure decision logic (timer, battery, app triggers) – no AppKit, fully unit-tested.
        .target(name: "WachmacherCore"),
        // Menu bar app: status item, settings window, power assertions, updates.
        .executableTarget(
            name: "Wachmacher",
            dependencies: ["WachmacherCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [
                // Sparkle.framework is embedded in Contents/Frameworks by scripts/build.sh.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(name: "WachmacherCoreTests", dependencies: ["WachmacherCore"]),
    ]
)
