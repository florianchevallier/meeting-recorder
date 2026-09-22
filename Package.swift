// swift-tools-version: 6.2
import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),  // SE-0461
    .enableUpcomingFeature("InferIsolatedConformances"),  // SE-0470
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "MeetingRecorder",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "MeetingRecorder",
            targets: ["MeetingRecorder"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MeetingRecorder",
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "MeetingRecorderTests",
            dependencies: ["MeetingRecorder"],
            path: "Tests",
            swiftSettings: sharedSwiftSettings
        ),
    ]
)
