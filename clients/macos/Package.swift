// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OwlMac",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "OwlMac", targets: ["OwlMac"]),
               .executable(name: "OwlDoctor", targets: ["OwlDoctor"])],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7", traits: []),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", exact: "2.28.0"),
        .package(url: "https://github.com/vapor/multipart-kit.git", exact: "4.7.1")
    ],
    targets: [
        .target(name: "OwlCore", dependencies: [
            .product(name: "FluidAudio", package: "FluidAudio"),
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "MultipartKit", package: "multipart-kit")
        ]),
        .executableTarget(name: "OwlMac", dependencies: ["OwlCore"]),
        .executableTarget(name: "OwlDoctor", dependencies: ["OwlCore"]),
        .testTarget(name: "OwlCoreTests", dependencies: ["OwlCore"])
    ]
)
