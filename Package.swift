// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacEverything",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacEverything", targets: ["MacEverything"])
    ],
    targets: [
        .executableTarget(
            name: "MacEverything",
            path: "Sources/MacEverything",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreServices"),
                .linkedFramework("QuickLookUI"),
                .linkedFramework("Carbon"),
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
