// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlitchDemoKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GlitchDemoKit", targets: ["GlitchDemoKit"]),
    ],
    targets: [
        .target(name: "GlitchDemoKit"),
        .testTarget(name: "GlitchDemoKitTests", dependencies: ["GlitchDemoKit"]),
    ],
    swiftLanguageModes: [.v5]
)
