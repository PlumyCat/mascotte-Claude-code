// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MascotteApp",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MascotteApp",
            path: "Sources/MascotteApp",
            resources: [
                // Silences the SPM "unhandled files" warning for bundled sounds.
                // Runtime resolution uses Bundle.main / a #filePath dev fallback
                // (see SoundPlayer.resolveSoundURL); the .app copies these into
                // Contents/Resources via scripts/build-app.sh.
                .copy("Resources/sounds")
            ]
        )
    ]
)
