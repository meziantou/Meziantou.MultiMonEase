// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "MultiMonEase",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "MultiMonEase", targets: ["MultiMonEase"]),
        .library(name: "MultiMonEaseCore", targets: ["MultiMonEaseCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "MultiMonEase",
            dependencies: ["MultiMonEaseCore"]
        ),
        .target(
            name: "MultiMonEaseCore"
        ),
        .testTarget(
            name: "MultiMonEaseTests",
            dependencies: [
                "MultiMonEaseCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
