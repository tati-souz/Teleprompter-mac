// swift-tools-version:5.9
// Abra este arquivo no Xcode (File ▸ Open…) ou compile com `./scripts/build-app.sh`.
import PackageDescription

let package = Package(
    name: "TeleprompterEthos",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TeleprompterEthos", targets: ["TeleprompterEthos"])
    ],
    targets: [
        // Lógica sem interface: modelos, rolagem, persistência, arquivos .txt, geometria de telas.
        .target(name: "TeleprompterCore"),
        // Aplicativo: AppKit (janelas, barra de menus, atalhos) + SwiftUI (editor, ajustes).
        .executableTarget(name: "TeleprompterEthos", dependencies: ["TeleprompterCore"]),
        .testTarget(name: "TeleprompterCoreTests", dependencies: ["TeleprompterCore"]),
    ]
)
