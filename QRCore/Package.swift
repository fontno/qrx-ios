// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QRCore",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(name: "QRCore", targets: ["QRCore"])
    ],
    targets: [
        .target(name: "QRCore"),
        .testTarget(name: "QRCoreTests", dependencies: ["QRCore"])
    ]
)
