// swift-tools-version:5.3

import PackageDescription

struct ProjectSettings {
    static let marketingVersion: String = "3.0.1"
}

let package = Package(
    name: "SRGDiagnostics",
    platforms: [
        .iOS(.v9),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(
            name: "SRGDiagnostics",
            targets: ["SRGDiagnostics"]
        )
    ],
    targets: [
        .target(
            name: "SRGDiagnostics",
            cSettings: [
                .define("MARKETING_VERSION", to: "\"\(ProjectSettings.marketingVersion)\"")
            ]
        ),
        .testTarget(
            name: "SRGDiagnosticsTests",
            dependencies: ["SRGDiagnostics"],
            cSettings: [
                .headerSearchPath("Private")
            ]
        )
    ]
)
