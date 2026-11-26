// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Gulir",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Gulir",
            path: "Sources/Gulir",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
