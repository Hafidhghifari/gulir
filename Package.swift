// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Gulir",
    platforms: [.macOS(.v13)],
    targets: [
        // Logika layout murni (tanpa AX/AppKit), bisa di-unit-test
        .target(
            name: "GulirCore",
            path: "Sources/GulirCore"
        ),
        .executableTarget(
            name: "Gulir",
            dependencies: ["GulirCore"],
            path: "Sources/Gulir",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(
            name: "GulirCoreTests",
            dependencies: ["GulirCore"],
            path: "Tests/GulirCoreTests"
        ),
    ]
)
