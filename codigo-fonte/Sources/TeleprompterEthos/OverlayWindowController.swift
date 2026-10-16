import AppKit
import Combine
import SwiftUI
import TeleprompterCore

/// Painel flutuante, sem bordas, transparente e que não ativa o app ao ser clicado.
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel, .resizable],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        // Nível de barra de status: acima de janelas comuns e de janelas "sempre no topo" (como as do OBS),
        // abaixo de menus, alertas do sistema e telas protegidas.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true   // botões e controles deslizantes não tiram o teclado do OBS
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        animationBehavior = .none
        minSize = NSSize(width: 460, height: 160)
        title = "Teleprompter — sobreposição"
    }

    override var canBecomeKey: Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { false }
}

/// Gerencia a janela da sobreposição: modos Ajustar/Ler, posição salva, telas e Spaces.
@MainActor
final class OverlayWindowController: NSObject, NSWindowDelegate {
    let panel: OverlayPanel
    let root: OverlayRootView
    private unowned let model: AppModel
    private var cancellables = Set<AnyCancellable>()
    private var pendingText: DispatchWorkItem?
    private var currentScriptID: UUID?

    init(model: AppModel) {
        self.model = model
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = ScreenGeometry.validatedFrame(
            saved: model.store.preferences.overlayFrame?.rect,
            screens: NSScreen.screens.map(\.visibleFrame),
            fallback: ScreenGeometry.defaultFrame(in: screen))
        panel = OverlayPanel(contentRect: frame)
        root = OverlayRootView(model: model)
        super.init()
        panel.contentView = root
        panel.delegate = self
        panel.setFrame(frame, display: false)

        let store = model.store
        store.$preferences
            .sink { [weak self] p in self?.applyPreferences(p) }
            .store(in: &cancellables)

        // Texto do roteiro selecionado (com pequeno atraso enquanto se digita no editor).
        store.$scripts.combineLatest(store.$preferences.map(\.selectedScriptID).removeDuplicates())
            .sink { [weak self] scripts, selected in
                let script = scripts.first { $0.id == selected } ?? scripts.first
                self?.scheduleText(script)
            }.store(in: &cancellables)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.ensureOnScreen() }
        }
    }

    // MARK: Visibilidade

    /// Mostra sem ativar o app nem tirar o foco de quem estiver em uso (OBS, por exemplo).
    func show() {
        ensureOnScreen()
        panel.orderFrontRegardless()
    }

    func hide() { panel.orderOut(nil) }

    func refresh() { root.textView.needsDisplay = true }

    // MARK: Modos

    func apply(mode: AppModel.Mode) {
        let reading = mode == .read
        panel.ignoresMouseEvents = reading
        panel.isMovableByWindowBackground = !reading
        if reading, panel.isKeyWindow { panel.resignKey() }
        root.setAdjusting(!reading)
    }

    // MARK: Preferências e texto

    private func applyPreferences(_ p: Preferences) {
        root.apply(p)
        panel.sharingType = p.excludeFromCapture ? .none : .readOnly
    }

    private func scheduleText(_ script: Script?) {
        pendingText?.cancel()
        let changedScript = script?.id != currentScriptID
        let apply = { [weak self] in
            guard let self else { return }
            self.currentScriptID = script?.id
            self.root.textView.setText(script?.body ?? "", resetPosition: changedScript)
        }
        if changedScript || root.textView.isEmptyLayout {
            apply()
        } else {
            let work = DispatchWorkItem(block: apply)
            pendingText = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }

    // MARK: Posição e telas

    /// Recoloca a janela numa área visível (ex.: monitor desconectado).
    func ensureOnScreen() {
        let screens = NSScreen.screens.map(\.visibleFrame)
        let fallbackScreen = NSScreen.main?.visibleFrame ?? screens.first ?? panel.frame
        let target = ScreenGeometry.validatedFrame(saved: panel.frame, screens: screens,
                                                   fallback: ScreenGeometry.defaultFrame(in: fallbackScreen))
        if target != panel.frame {
            panel.setFrame(target, display: true)
            saveFrame()
        }
    }

    /// Muda o tamanho mantendo o canto superior esquerdo no lugar (alternativa às bordas).
    func resize(width: CGFloat? = nil, height: CGFloat? = nil) {
        var f = panel.frame
        let top = f.maxY
        if let width { f.size.width = max(panel.minSize.width, width) }
        if let height { f.size.height = max(panel.minSize.height, height) }
        f.origin.y = top - f.height
        panel.setFrame(f, display: true)
        ensureOnScreen()
        saveFrame()
    }

    /// Volta ao tamanho e à posição padrão (faixa no alto da tela principal, perto da câmera).
    func resetFrame() {
        let screen = NSScreen.main?.visibleFrame ?? panel.frame
        panel.setFrame(ScreenGeometry.defaultFrame(in: screen), display: true)
        saveFrame()
    }

    func saveFrame() {
        let f = SavedFrame(panel.frame)
        if model.store.preferences.overlayFrame != f { model.store.preferences.overlayFrame = f }
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }
}
