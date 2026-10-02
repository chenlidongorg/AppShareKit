// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppShareKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13)
    ],
    products: [
        .library(name: "ScienceLabUI", targets: ["ScienceLabUI"]),
        .library(
            name: "AppShareKit",
            targets: ["AppShareKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(name: "ScienceLabUI", resources: [.process("Resources")]),
        .testTarget(name: "ScienceLabUITests", dependencies: ["ScienceLabUI"]),
        .target(
            name: "AppShareKit",
            dependencies: []
        ),
        .testTarget(
            name: "AppShareKitTests",
            dependencies: ["AppShareKit"]
        )
    ]
)
