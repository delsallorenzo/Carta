// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Carta",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Carta", targets: ["CartaApp"])
    ],
    targets: [
        .executableTarget(
            name: "CartaApp",
            path: "Sources/CartaApp"
        )
    ]
)
