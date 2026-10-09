// swift-tools-version: 6.0
import PackageDescription

// CaixaPretaFormato: evento, filtro e formato do arquivo (iOS e Mac).
let package = Package(
    name: "caixa-preta",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "CaixaPretaFormato"),
        .target(name: "ApoioDosTestes", path: "Tests/ApoioDosTestes"),
        .testTarget(name: "CaixaPretaFormatoTests", dependencies: ["CaixaPretaFormato", "ApoioDosTestes"]),
    ]
)
