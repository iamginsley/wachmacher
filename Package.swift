// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wachmacher",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure decision logic (timer, battery, app triggers) – no AppKit, fully unit-tested.
        .target(name: "WachmacherCore"),
        // Menu bar app: status item, settings window, power assertions.
        .executableTarget(name: "Wachmacher", dependencies: ["WachmacherCore"]),
        .testTarget(name: "WachmacherCoreTests", dependencies: ["WachmacherCore"]),
    ]
)
