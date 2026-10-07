// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BodyAgeCore",
    platforms: [.watchOS(.v10), .macOS(.v13)],
    products: [.library(name: "BodyAgeCore", targets: ["BodyAgeCore"])],
    targets: [
        .target(name: "BodyAgeCore"),
        .testTarget(name: "BodyAgeCoreTests", dependencies: ["BodyAgeCore"])
    ]
)
