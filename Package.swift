// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MeetingRecorder",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MeetingRecorder",
            targets: ["MeetingRecorder"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "MeetingRecorder",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MeetingRecorderTests",
            dependencies: ["MeetingRecorder"],
            path: "Tests"
        ),
    ]
)