// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MeetingRecorder",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "MeetingRecorder",
            targets: ["MeetingRecorder"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MeetingRecorder",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "MeetingRecorderTests",
            dependencies: ["MeetingRecorder"],
            path: "Tests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                // Locate Testing.framework when building with Command Line Tools
                // (it ships outside the default search path there)
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                // Locate Testing.framework when building with Command Line Tools
                // (it ships outside the default search path there)
                .unsafeFlags([
                    "-Xlinker", "-F", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        ),
    ]
)
