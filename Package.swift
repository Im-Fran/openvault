// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "OpenVault",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "OpenVaultCore", targets: ["OpenVaultCore"]),
        .executable(name: "ovault", targets: ["ovault"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "OpenVaultCore"),
        .executableTarget(name: "ovault", dependencies: [
            "OpenVaultCore",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "OpenVaultCoreTests", dependencies: ["OpenVaultCore"]),
    ]
)
