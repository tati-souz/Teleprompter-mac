import AppKit
import Combine
import TeleprompterCore

/// Ícone na barra de menus: o caminho que sempre funciona para sair do modo Ler.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private unowned let model: AppModel
    private var cancellables = Set<AnyCancellable>()

    init(model: AppModel) {
        self.model = model
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        item.button?.toolTip = "Teleprompter Ethos"

        model.$mode.combineLatest(model.store.$lastError.map { $0 != nil }, model.$overlayVisible)
            .sink { [weak self] mode, hasError, _ in self?.updateIcon(mode: mode, hasError: hasError) }
            .store(in: &cancellables)
    }

    private func updateIcon(mode: AppModel.Mode, hasError: Bool) {
        let name: String
        if hasError { name = "exclamationmark.triangle.fill" } else { name = mode == .read ? "scroll.fill" : "scroll" }
        let desc = mode == .read ? "Teleprompter Ethos — modo Ler" : "Teleprompter Ethos — modo Ajustar"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: desc)
        image?.isTemplate = true
        item.button?.image = image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let prefs = model.store.preferences

        let title = model.store.selectedScript?.title ?? "Sem roteiro"
        let header = NSMenuItem(title: "\(model.stateDescription) · \(Int(model.engine.speed.rounded())) pt/s", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let scriptLine = NSMenuItem(title: "Roteiro: \(title)", action: nil, keyEquivalent: "")
        scriptLine.isEnabled = false
        menu.addItem(scriptLine)

        if let err = model.store.lastError {
            menu.addItem(.separator())
            let e = add("⚠︎ Falha ao salvar — tentar novamente", nil) { [weak self] in self?.model.retrySave() }
            e.toolTip = err
            add("Ver detalhes no editor", nil) { [weak self] in self?.model.windows.showEditor() }
        }

        menu.addItem(.separator())
        if model.mode == .read {
            let back = add("Voltar ao modo Ajustar", prefs.hotkey(for: .toggleMode)) { [weak self] in self?.model.setMode(.adjust) }
            back.attributedTitle = NSAttributedString(string: back.title, attributes: [.font: NSFont.menuFont(ofSize: 0).bold])
        }
        add("Abrir editor de roteiros…", nil) { [weak self] in self?.model.windows.showEditor() }
        add("Ajustes…", nil) { [weak self] in self?.model.windows.showSettings() }

        menu.addItem(.separator())
        add(model.overlayVisible ? "Esconder sobreposição" : "Mostrar sobreposição", prefs.hotkey(for: .toggleOverlay)) { [weak self] in
            self?.model.toggleOverlay()
        }
        add(model.playPauseTitle, prefs.hotkey(for: .playPause)) { [weak self] in self?.model.togglePlayPause() }
        add("Voltar ao começo", prefs.hotkey(for: .rewind)) { [weak self] in self?.model.rewind() }
        add("Aumentar velocidade (+\(Int(Preferences.speedStep)) pt/s)", prefs.hotkey(for: .faster)) { [weak self] in self?.model.faster() }
        add("Diminuir velocidade (−\(Int(Preferences.speedStep)) pt/s)", prefs.hotkey(for: .slower)) { [weak self] in self?.model.slower() }

        menu.addItem(.separator())
        let adjust = add("Modo Ajustar (mover, redimensionar, controles)", model.mode == .read ? nil : prefs.hotkey(for: .toggleMode)) { [weak self] in
            self?.model.setMode(.adjust)
        }
        adjust.state = model.mode == .adjust ? .on : .off
        let read = add("Modo Ler (cliques atravessam)", nil) { [weak self] in self?.model.setMode(.read) }
        read.state = model.mode == .read ? .on : .off
        add("Restaurar tamanho e posição da sobreposição", nil) { [weak self] in
            self?.model.setMode(.adjust)
            self?.model.showOverlay()
            self?.model.overlay.resetFrame()
        }

        let scriptsItem = NSMenuItem(title: "Roteiro", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for s in model.store.scripts {
            let i = ClosureMenuItem(title: s.title) { [weak self] in self?.model.selectScript(s.id) }
            i.state = s.id == model.store.selectedScript?.id ? .on : .off
            sub.addItem(i)
        }
        scriptsItem.submenu = sub
        menu.addItem(scriptsItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Encerrar Teleprompter Ethos", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @discardableResult
    private func add(_ title: String, _ combo: KeyCombo?, _ action: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, handler: action)
        if let combo { item.setShortcutDisplay(combo) }
        menu.addItem(item)
        return item
    }
}

/// Item de menu que executa um bloco.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }

    /// Mostra o atalho global ao lado do item (só exibição, quando possível).
    func setShortcutDisplay(_ combo: KeyCombo) {
        let name = KeyCombo.keyName(combo.keyCode)
        guard name.count == 1 else {
            title += "   \(combo.displayString)"
            return
        }
        keyEquivalent = name.lowercased()
        var mask: NSEvent.ModifierFlags = []
        if combo.modifiers & KeyCombo.command != 0 { mask.insert(.command) }
        if combo.modifiers & KeyCombo.shift != 0 { mask.insert(.shift) }
        if combo.modifiers & KeyCombo.option != 0 { mask.insert(.option) }
        if combo.modifiers & KeyCombo.control != 0 { mask.insert(.control) }
        keyEquivalentModifierMask = mask
    }
}

private extension NSFont {
    var bold: NSFont { NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask) }
}
