// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppShareKit",
    platforms: [
        .iOS(.v13),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: "AppShareKit",
            targets: ["AppShareKit"]
        )
    ],
    dependencies: [],
    targets: [
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
