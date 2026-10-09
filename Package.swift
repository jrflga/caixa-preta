// swift-tools-version: 6.0
import PackageDescription

// CaixaPretaFormato: evento, filtro e formato do arquivo (iOS e Mac).
// CaixaPreta: o que o app liga.
let package = Package(
    name: "caixa-preta",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CaixaPreta", targets: ["CaixaPreta"]),
    ],
    targets: [
        .target(name: "CaixaPretaFormato"),
        .target(name: "CaixaPreta", dependencies: ["CaixaPretaFormato"]),
        .target(name: "ApoioDosTestes", path: "Tests/ApoioDosTestes"),
        .testTarget(name: "CaixaPretaFormatoTests", dependencies: ["CaixaPretaFormato", "ApoioDosTestes"]),
        .testTarget(name: "CaixaPretaTests", dependencies: ["CaixaPreta", "ApoioDosTestes"]),
    ]
)
