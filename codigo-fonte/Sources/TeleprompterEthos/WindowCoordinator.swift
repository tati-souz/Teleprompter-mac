import AppKit
import SwiftUI
import TeleprompterCore

/// Janelas comuns (editor e ajustes). Enquanto alguma está aberta, o app aparece no Dock
/// e tem menu; quando todas fecham, volta a ser apenas o ícone da barra de menus.
@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {
    private unowned let model: AppModel
    private(set) var editorWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func showEditor() {
        if editorWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Roteiros — Teleprompter Ethos"
            let host = NSHostingController(rootView: EditorView(model: model, store: model.store, engine: model.engine))
            host.sizingOptions = []   // o tamanho da janela é da pessoa, não do conteúdo
            w.contentViewController = host
            w.minSize = NSSize(width: 820, height: 460)
            w.setContentSize(NSSize(width: 980, height: 640))
            w.setFrameAutosaveName("EditorWindow")
            if !w.setFrameUsingName("EditorWindow") { w.center() }
            w.isReleasedWhenClosed = false
            w.delegate = self
            editorWindow = w
        }
        present(editorWindow!)
    }

    func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = "Ajustes — Teleprompter Ethos"
            let host = NSHostingController(rootView: SettingsView(model: model, store: model.store, engine: model.engine))
            host.sizingOptions = []
            w.contentViewController = host
            w.minSize = NSSize(width: 560, height: 480)
            w.setContentSize(NSSize(width: 620, height: 600))
            w.setFrameAutosaveName("SettingsWindow")
            if !w.setFrameUsingName("SettingsWindow") { w.center() }
            w.isReleasedWhenClosed = false
            w.delegate = self
            settingsWindow = w
        }
        present(settingsWindow!)
    }

    private func present(_ w: NSWindow) {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === settingsWindow { model.endRecording() }
        let others = [editorWindow, settingsWindow].compactMap { $0 }.filter { $0 !== closing && $0.isVisible }
        if others.isEmpty {
            try? model.store.saveNow()
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        }
    }
}

/// Menu principal (visível quando o editor está aberto). Garante ⌘C, ⌘V, ⌘Z etc. no editor.
@MainActor
enum MainMenuBuilder {
    static func install(model: AppModel) {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(ClosureMenuItem(title: "Ajustes…") { model.windows.showSettings() }.withKey(","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Ocultar Teleprompter Ethos", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Encerrar Teleprompter Ethos", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let file = NSMenu(title: "Arquivo")
        file.addItem(ClosureMenuItem(title: "Novo roteiro") { model.newScript(); model.windows.showEditor() }.withKey("n"))
        file.addItem(ClosureMenuItem(title: "Importar .txt…") { model.importScripts(from: model.windows.editorWindow) }.withKey("o"))
        file.addItem(ClosureMenuItem(title: "Exportar roteiro como .txt…") { model.exportSelected(from: model.windows.editorWindow) }.withKey("e"))
        file.addItem(.separator())
        file.addItem(NSMenuItem(title: "Fechar janela", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileItem.submenu = file
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Editar")
        edit.addItem(NSMenuItem(title: "Desfazer", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Refazer", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Recortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Colar", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        let pastePlain = NSMenuItem(title: "Colar sem formatação", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "v")
        pastePlain.keyEquivalentModifierMask = [.command, .option, .shift]
        edit.addItem(pastePlain)
        edit.addItem(NSMenuItem(title: "Selecionar tudo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        edit.addItem(.separator())
        let find = NSMenuItem(title: "Buscar…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        edit.addItem(find)
        editItem.submenu = edit
        main.addItem(editItem)

        let tpItem = NSMenuItem()
        let tp = NSMenu(title: "Teleprompter")
        tp.addItem(ClosureMenuItem(title: "Mostrar / esconder sobreposição") { model.toggleOverlay() })
        tp.addItem(ClosureMenuItem(title: "Iniciar / pausar leitura") { model.togglePlayPause() })
        tp.addItem(ClosureMenuItem(title: "Voltar ao começo") { model.rewind() })
        tp.addItem(ClosureMenuItem(title: "Alternar Ajustar / Ler") { model.toggleMode() })
        tpItem.submenu = tp
        main.addItem(tpItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: "Janela")
        window.addItem(NSMenuItem(title: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        window.addItem(ClosureMenuItem(title: "Editor de roteiros") { model.windows.showEditor() }.withKey("1"))
        windowItem.submenu = window
        main.addItem(windowItem)
        NSApp.windowsMenu = window

        NSApp.mainMenu = main
    }
}

extension NSMenuItem {
    func withKey(_ key: String, _ mask: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        keyEquivalent = key
        keyEquivalentModifierMask = mask
        return self
    }
}
