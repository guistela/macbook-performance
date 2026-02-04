// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ActivityMonPlus",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ActivityMonPlus", targets: ["ActivityMonPlus"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CSMC-T2",
            path: "Sources/CSMC-T2",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "ActivityMonPlus",
            dependencies: ["CSMC-T2"],
            path: "Sources/MacbookPerformance"
        ),
        .executableTarget(
            name: "SMCDiagnostic",
            dependencies: ["CSMC-T2"],
            path: "Sources/SMCDiagnostic"
        )
    ]
)
