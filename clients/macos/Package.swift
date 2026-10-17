// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RecapMac",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "RecapMac", targets: ["RecapMac"]),
               .executable(name: "RecapDoctor", targets: ["RecapDoctor"])],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7", traits: []),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", exact: "2.28.0"),
        .package(url: "https://github.com/vapor/multipart-kit.git", exact: "4.7.1")
    ],
    targets: [
        .target(name: "RecapCore", dependencies: [
            .product(name: "FluidAudio", package: "FluidAudio"),
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "MultipartKit", package: "multipart-kit")
        ]),
        .executableTarget(name: "RecapMac", dependencies: ["RecapCore"]),
        .executableTarget(name: "RecapDoctor", dependencies: ["RecapCore"]),
        .testTarget(name: "RecapCoreTests", dependencies: ["RecapCore"])
    ]
)
