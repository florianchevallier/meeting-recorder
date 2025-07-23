// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MeetingRecorder",
    platforms: [
        .macOS(.v12)
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
            path: "Sources"
        ),
        .testTarget(
            name: "MeetingRecorderTests",
            dependencies: ["MeetingRecorder"],
            path: "Tests"
        ),
    ]
)