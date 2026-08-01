// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusicMixer",
    platforms: [.macOS("14.4")],  // process-tap APIs (AudioHardwareCreateProcessTap)
    targets: [
        .executableTarget(
            name: "MusicMixer",
            path: "Sources/MusicMixer",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "MusicMixerTests",
            dependencies: ["MusicMixer"],
            path: "Tests/MusicMixerTests"
        ),
    ]
)
