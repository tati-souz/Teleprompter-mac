import AppKit
import Combine
import UniformTypeIdentifiers
import TeleprompterCore

/// Coordena as partes do app: persistência (Store), rolagem (ScrollEngine),
/// sobreposição (OverlayWindowController), atalhos globais e janelas de edição.
@MainActor
final class AppModel: ObservableObject {
    enum Mode { case adjust, read }

    @Published private(set) var mode: Mode = .adjust
    @Published private(set) var overlayVisible = false
    /// Problemas de atalho por ação (chave = HotkeyAction.rawValue).
    @Published private(set) var hotkeyIssues: [String: String] = [:]
    @Published private(set) var recordingAction: HotkeyAction?
    @Published var recordingMessage: String?

    let store: Store
    let engine: ScrollEngine
    private(set) var overlay: OverlayWindowController!
    private(set) var windows: WindowCoordinator!
    private let hotkeys = HotkeyManager()
    private var cancellables = Set<AnyCancellable>()
    private var recordMonitor: Any?

    init(store: Store) {
        self.store = store
        engine = ScrollEngine(speed: store.preferences.speed,
                              countdownSeconds: Double(store.preferences.countdown.rawValue))
        overlay = OverlayWindowController(model: self)
        windows = WindowCoordinator(model: self)

        // Velocidade: motor ⇄ preferências.
        engine.$speed.dropFirst().removeDuplicates()
            .sink { [weak self] v in
                guard let self, self.store.preferences.speed != v else { return }
                self.store.preferences.speed = v
            }.store(in: &cancellables)
        store.$preferences.map(\.speed).removeDuplicates()
            .sink { [weak self] v in
                guard let self, self.engine.speed != v else { return }
                self.engine.speed = v
            }.store(in: &cancellables)
        store.$preferences.map(\.countdown).removeDuplicates()
            .sink { [weak self] c in self?.engine.countdownSeconds = Double(c.rawValue) }
            .store(in: &cancellables)
        store.$preferences.map(\.hotkeys).removeDuplicates().dropFirst()
            .sink { [weak self] _ in
                guard let self, self.recordingAction == nil else { return }
                DispatchQueue.main.async { self.applyHotkeys() }
            }.store(in: &cancellables)

        hotkeys.onAction = { [weak self] action in self?.perform(action) }

        // Suspensão: pausa e evita saltos ao reativar.
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleSleep() }
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleWake() }
            }
        }
    }

    func start() {
        applyHotkeys()
        // Ao abrir, a sobreposição sempre começa em Ajustar: nunca inicia ignorando cliques.
        setMode(.adjust)
        if store.preferences.overlayVisible { showOverlay() }
    }

    func prepareForTermination() {
        engine.pause()
        overlay.saveFrame()
        try? store.saveNow()
    }

    // MARK: Ações

    func perform(_ action: HotkeyAction) {
        switch action {
        case .playPause: togglePlayPause()
        case .faster: faster()
        case .slower: slower()
        case .toggleOverlay: toggleOverlay()
        case .toggleMode: toggleMode()
        case .rewind: rewind()
        }
    }

    func togglePlayPause() {
        if !overlayVisible { showOverlay() }
        engine.togglePlayPause()
        overlay.refresh()
    }

    func faster() { engine.speed = ScrollEngine.clampSpeed(engine.speed + Preferences.speedStep) }
    func slower() { engine.speed = ScrollEngine.clampSpeed(engine.speed - Preferences.speedStep) }

    func rewind() {
        engine.rewind()
        overlay.refresh()
    }

    func toggleMode() { setMode(mode == .adjust ? .read : .adjust) }

    func setMode(_ m: Mode) {
        mode = m
        overlay.apply(mode: m)
        // Ao voltar para Ajustar, garante que a janela esteja visível e alcançável.
        if m == .adjust, overlayVisible { overlay.ensureOnScreen() }
    }

    func toggleOverlay() { overlayVisible ? hideOverlay() : showOverlay() }

    func showOverlay() {
        overlay.show()
        overlayVisible = true
        if !store.preferences.overlayVisible { store.preferences.overlayVisible = true }
    }

    func hideOverlay() {
        engine.pause()
        overlay.hide()
        overlayVisible = false
        if store.preferences.overlayVisible { store.preferences.overlayVisible = false }
    }

    func selectScript(_ id: UUID?) {
        guard let id, store.preferences.selectedScriptID != id else { return }
        store.preferences.selectedScriptID = id
    }

    func changeFontSize(by delta: Double) {
        let r = Preferences.fontSizeRange
        store.preferences.fontSize = min(max(store.preferences.fontSize + delta, r.lowerBound), r.upperBound)
    }

    // MARK: Suspensão

    private var wasSleeping = false

    private func handleSleep() {
        wasSleeping = true
        engine.pause()
        engine.resetClock()
        overlay.refresh()
    }

    private func handleWake() {
        guard wasSleeping else { return }
        wasSleeping = false
        engine.resetClock()
        overlay.ensureOnScreen()
        overlay.refresh()
    }

    // MARK: Atalhos

    func applyHotkeys() {
        hotkeyIssues = hotkeys.register(store.preferences.hotkeys)
    }

    func beginRecording(_ action: HotkeyAction) {
        endRecording()
        recordingAction = action
        recordingMessage = nil
        hotkeys.unregisterAll()   // permite gravar inclusive a combinação já em uso por este app
        // Monitor LOCAL: só vê teclas enviadas a este app enquanto a janela de ajustes está ativa.
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let code = event.keyCode
            let flags = event.modifierFlags
            let consumed = MainActor.assumeIsolated { self.handleRecording(keyCode: code, flags: flags) }
            return consumed ? nil : event
        }
    }

    func endRecording() {
        if let m = recordMonitor { NSEvent.removeMonitor(m) }
        recordMonitor = nil
        if recordingAction != nil {
            recordingAction = nil
            applyHotkeys()
        }
    }

    private func handleRecording(keyCode: UInt16, flags rawFlags: NSEvent.ModifierFlags) -> Bool {
        guard let action = recordingAction else { return false }
        let flags = rawFlags.intersection(.deviceIndependentFlagsMask)
        if keyCode == 53, flags.intersection([.command, .control, .option]).isEmpty {
            recordingMessage = nil
            endRecording()
            return true
        }
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= KeyCombo.command }
        if flags.contains(.shift) { mods |= KeyCombo.shift }
        if flags.contains(.option) { mods |= KeyCombo.option }
        if flags.contains(.control) { mods |= KeyCombo.control }
        let combo = KeyCombo(keyCode: UInt32(keyCode), modifiers: mods)
        guard combo.isAllowedGlobalShortcut else {
            recordingMessage = "Use F7 ou F8 sozinhas, ou ⌘, ⌃ ou ⌥ junto com outra tecla. (Esc cancela)"
            return true
        }
        recordingMessage = nil
        store.preferences.hotkeys[action.rawValue] = combo
        endRecording()
        return true
    }

    func restoreDefaultHotkeys() {
        endRecording()
        store.preferences.hotkeys = KeyCombo.defaults
        applyHotkeys()
    }

    // MARK: Roteiros (importar / exportar / excluir)

    func newScript() {
        store.addScript()
    }

    func importScripts(from window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Escolha um ou mais arquivos .txt"
        panel.prompt = "Importar"
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK else { return }
            MainActor.assumeIsolated { self.importFiles(panel.urls, window: window) }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: handle) } else { handle(panel.runModal()) }
    }

    func importFiles(_ urls: [URL], window: NSWindow?) {
        var notes: [String] = []
        for url in urls {
            do {
                let result = try TextFileIO.read(url)
                store.addScript(title: TextFileIO.title(from: url), body: result.text)
                if let enc = result.fallbackEncoding {
                    notes.append("“\(url.lastPathComponent)” não estava em UTF-8; foi lido como \(enc). Confira os acentos.")
                }
            } catch {
                notes.append("“\(url.lastPathComponent)”: \(error.localizedDescription)")
            }
        }
        if !notes.isEmpty { showAlert("Importação", notes.joined(separator: "\n\n"), window: window) }
    }

    func exportSelected(from window: NSWindow?) {
        guard let script = store.selectedScript else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = TextFileIO.fileName(for: script.title)
        panel.message = "O arquivo será salvo em UTF-8."
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                do { try TextFileIO.write(script.body, to: url) } catch {
                    self.showAlert("Não foi possível exportar", error.localizedDescription, window: window)
                }
            }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: handle) } else { handle(panel.runModal()) }
    }

    func retrySave() {
        do { try store.saveNow() } catch {}
    }

    func showAlert(_ title: String, _ text: String, window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        if let window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }

    // MARK: Descrições para menus

    var stateDescription: String {
        switch engine.state {
        case .idle: return "Parado no início"
        case .countingDown: return "Contagem regressiva"
        case .playing: return "Lendo"
        case .paused: return "Pausado"
        case .finished: return "Fim do roteiro"
        }
    }

    var playPauseTitle: String {
        switch engine.state {
        case .playing, .countingDown: return "Pausar leitura"
        case .paused: return "Retomar leitura"
        default: return "Iniciar leitura"
        }
    }
}
