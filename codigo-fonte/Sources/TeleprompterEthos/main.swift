import AppKit

// Ponto de entrada. O app começa como "acessório" (ícone apenas na barra de menus);
// vira um app comum, com Dock e menu, enquanto o editor ou os ajustes estão abertos.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) {
        app.run()
    }
}
