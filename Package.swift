// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JemWallpaperConverter",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "JemWallpaperConverter",
            dependencies: [],
            path: "Sources"
        )
    ]
)
