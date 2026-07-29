// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// Command Line Tools ship Testing.framework outside the default search path.
// Full Xcode installs (e.g. CI) already resolve it correctly, and forcing this
// search path there shadows Xcode's own Testing.framework with an incompatible
// one, breaking @Test macro expansion. Only add it when CLT is the active
// developer directory.
func isUsingCommandLineTools() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    process.arguments = ["-p"]
    let pipe = Pipe()
    process.standardOutput = pipe
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8) ?? ""
        return path.contains("CommandLineTools")
    } catch {
        return false
    }
}

var testSwiftSettings: [SwiftSetting] = []
var testLinkerSettings: [LinkerSetting] = []

if isUsingCommandLineTools() {
    testSwiftSettings.append(
        .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
    )
    testLinkerSettings.append(
        .unsafeFlags([
            "-Xlinker", "-F", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
            "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
            "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
        ])
    )
}

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
            ]
        ),
        .testTarget(
            name: "MeetingRecorderTests",
            dependencies: ["MeetingRecorder"],
            path: "Tests",
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ]
)
