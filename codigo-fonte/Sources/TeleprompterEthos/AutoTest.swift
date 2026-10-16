import AppKit
import TeleprompterCore

/// Roteiro de verificação automática executado dentro do app real (`--autotest <arquivo.json>`).
/// Usa uma pasta de dados separada (`--data-dir`) para não tocar nos roteiros da pessoa.
@MainActor
final class AutoTest {
    private let model: AppModel
    private let output: URL
    private let quitWhenDone: Bool
    /// App que fica em primeiro plano durante o teste (padrão: Finder; ex.: com.obsproject.obs-studio).
    var frontAppBundleID = "com.apple.finder"
    /// Se definido, salva imagens das janelas do próprio app (não exige permissão de gravação de tela).
    var snapshotDirectory: URL?
    private var results: [[String: Any]] = []

    init(model: AppModel, output: URL, quitWhenDone: Bool) {
        self.model = model
        self.output = output
        self.quitWhenDone = quitWhenDone
    }

    func run() {
        Task { @MainActor in
            await scenario()
            if snapshotDirectory != nil { await snapshots() }
            write()
            if quitWhenDone { NSApp.terminate(nil) }
        }
    }

    private func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        results.append(["teste": name, "ok": ok, "detalhe": detail])
        print("[\(ok ? "OK" : "FALHA")] \(name) \(detail)")
    }

    private func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }

    private func near(_ value: Double, _ expected: Double, tolerance: Double = 0.25) -> Bool {
        abs(value - expected) <= expected * tolerance
    }

    private func scenario() async {
        let engine = model.engine
        let panel = model.overlay.panel
        let store = model.store
        let paragraphs = (1...40).map { "Parágrafo \($0): a virtude não nasce do impulso, mas do hábito — ação, coração, você, já." }
        store.addScript(title: "Teste automático", body: paragraphs.joined(separator: "\n\n"))
        store.preferences.countdown = .off
        store.preferences.fontSize = 44
        engine.speed = 60
        await wait(0.5)

        // Outro app em primeiro plano (Finder ou OBS), como durante a gravação.
        NSRunningApplication.runningApplications(withBundleIdentifier: frontAppBundleID).first?.activate()
        await wait(1.5)
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        check("Outro app em foco antes dos testes", front != Bundle.main.bundleIdentifier, front)

        model.hideOverlay()
        await wait(0.3)
        model.showOverlay()
        await wait(0.6)
        let front2 = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        check("Mostrar sobreposição não rouba o foco", !NSApp.isActive && front2 == front, "app em foco: \(front2)")
        check("Sobreposição visível na tela", panel.isVisible && panel.occlusionState.contains(.visible),
              "nível \(panel.level.rawValue), frame \(NSStringFromRect(panel.frame))")
        check("Comportamento em Spaces / tela cheia",
              panel.collectionBehavior.contains(.canJoinAllSpaces) && panel.collectionBehavior.contains(.fullScreenAuxiliary))
        check("Não ativa o app ao clicar (painel não ativador)", panel.styleMask.contains(.nonactivatingPanel))

        checkWindowOrder(front: front)

        // Os testes de tempo rodam no modo Ler (uso real): mouse e trackpad atravessam a janela
        // e não interferem — no modo Ajustar, rolar sobre a sobreposição reposiciona o texto.
        model.setMode(.read)

        // Rolagem com outro app em foco.
        model.rewind()
        model.togglePlayPause()
        await wait(2.0)
        let o1 = engine.offset
        check("Rola com outro app em foco (60 pt/s × 2 s ≈ 120 pt)", near(o1, 120) && !NSApp.isActive,
              String(format: "avançou %.1f pt; app ativo: %@", o1, NSApp.isActive ? "sim" : "não"))

        // Pausar preserva posição.
        model.togglePlayPause()
        let p = engine.offset
        await wait(1.0)
        check("Pausar mantém a posição", engine.offset == p && engine.state == .paused, String(format: "%.2f → %.2f", p, engine.offset))

        // Retomar continua do ponto.
        model.togglePlayPause()
        await wait(1.0)
        check("Retomar continua de onde parou", near(engine.offset - p, 60), String(format: "+%.1f pt em 1 s", engine.offset - p))

        // Velocidade durante a leitura.
        engine.speed = 180
        let a = engine.offset
        await wait(1.0)
        check("Mudar velocidade durante a leitura (180 pt/s)", near(engine.offset - a, 180), String(format: "+%.1f pt em 1 s", engine.offset - a))
        model.faster()
        check("Atalho/ação de aumentar velocidade (+5)", engine.speed == 185, "\(engine.speed)")
        model.slower(); model.slower()
        check("Diminuir velocidade (−5 ×2)", engine.speed == 175, "\(engine.speed)")
        check("Velocidade salva nas preferências", store.preferences.speed == 175, "\(store.preferences.speed)")
        engine.speed = 60
        model.togglePlayPause()

        // Contagem regressiva.
        store.preferences.countdown = .three
        await wait(0.1)
        let before = engine.offset
        model.togglePlayPause()
        await wait(1.0)
        var counting = false
        if case .countingDown = engine.state { counting = true }
        check("Contagem regressiva de 3 s em andamento", counting && engine.offset == before)
        await wait(2.6)
        check("Após a contagem, rola", engine.state == .playing && engine.offset > before, String(format: "%.1f → %.1f", before, engine.offset))
        model.togglePlayPause()
        store.preferences.countdown = .off
        await wait(0.1)

        // Suspensão do Mac (notificações simuladas).
        model.togglePlayPause()
        await wait(0.5)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: NSWorkspace.shared)
        let s = engine.offset
        check("Ao suspender, a leitura pausa", engine.state == .paused)
        await wait(1.0)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: NSWorkspace.shared)
        await wait(0.5)
        check("Ao reativar, continua pausado e sem salto", engine.state == .paused && engine.offset == s,
              String(format: "%.2f → %.2f", s, engine.offset))

        // Preservar o trecho em leitura ao mudar fonte/largura/espaçamento.
        engine.setOffset(engine.maxOffset * 0.45)
        await wait(0.2)
        let ci = model.overlay.root.textView.focusedCharacterIndex ?? -1
        store.preferences.fontSize = 64
        await wait(0.2)
        let ci2 = model.overlay.root.textView.focusedCharacterIndex ?? -1
        store.preferences.readingWidth = 0.6
        store.preferences.lineSpacing = 1.6
        await wait(0.2)
        let ci3 = model.overlay.root.textView.focusedCharacterIndex ?? -1
        let text = store.selectedScript?.body ?? ""
        func lineOf(_ i: Int) -> String {
            guard i >= 0, i < text.count else { return "?" }
            let idx = text.index(text.startIndex, offsetBy: i)
            return String(text[text.index(idx, offsetBy: -min(10, i))..<text.index(idx, offsetBy: min(10, text.count - i))])
        }
        check("Mudar fonte preserva o trecho em leitura", ci >= 0 && abs(ci2 - ci) <= 60,
              "caractere \(ci) → \(ci2) («\(lineOf(ci))» → «\(lineOf(ci2))»)")
        check("Mudar largura e espaçamento preserva o trecho", ci >= 0 && abs(ci3 - ci) <= 80, "caractere \(ci) → \(ci3)")
        store.preferences.fontSize = 44
        store.preferences.readingWidth = 0.9
        store.preferences.lineSpacing = 1.25
        await wait(0.2)

        // Fim do roteiro.
        engine.speed = 120
        engine.setOffset(engine.maxOffset - 40)
        model.togglePlayPause()
        await wait(1.5)
        check("Para sozinho no fim do roteiro", engine.state == .finished && engine.offset == engine.maxOffset,
              String(format: "estado %@, %.1f/%.1f", "\(engine.state)", engine.offset, engine.maxOffset))
        model.togglePlayPause()
        await wait(0.2)
        check("Iniciar após o fim recomeça do início", engine.offset < 30, String(format: "%.1f", engine.offset))
        model.togglePlayPause()
        model.rewind()
        check("Voltar ao começo", engine.offset == 0 && engine.state == .idle)
        engine.speed = 60

        // Modos Ajustar / Ler.
        model.setMode(.read)
        await wait(0.2)
        check("Modo Ler: cliques atravessam (ignoresMouseEvents)", panel.ignoresMouseEvents && !panel.canBecomeKey)
        model.perform(.toggleMode) // mesmo caminho do atalho global e do menu
        await wait(0.2)
        check("Voltar a Ajustar pela ação do atalho/menu", !panel.ignoresMouseEvents && model.mode == .adjust)

        // Recuperação de janela fora da tela (monitor desconectado).
        let saved = panel.frame
        panel.setFrame(NSRect(x: -30000, y: -30000, width: saved.width, height: saved.height), display: false)
        model.overlay.ensureOnScreen()
        let visible = NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
        check("Janela fora de qualquer tela volta para área visível", visible, NSStringFromRect(panel.frame))
        panel.setFrame(saved, display: true)
        check("Monitores conectados", true, "\(NSScreen.screens.count) tela(s): " + NSScreen.screens.map { NSStringFromRect($0.frame) }.joined(separator: ", "))

        // Redimensionar pelas bordas: arrasto simulado no canto inferior direito e na borda esquerda.
        await checkResizeHandles()

        // Atalhos registrados.
        check("Atalhos globais registrados sem conflito", model.hotkeyIssues.isEmpty, model.hotkeyIssues.description)

        // Persistência.
        do {
            try store.saveNow()
            let data = try Data(contentsOf: store.preferencesURL)
            let decoded = try JSONDecoder().decode(Preferences.self, from: data)
            check("Preferências gravadas em disco", decoded.speed == engine.speed, store.preferencesURL.path)
        } catch {
            check("Preferências gravadas em disco", false, error.localizedDescription)
        }
    }

    /// Usa a lista pública de janelas do sistema para confirmar que a sobreposição está na tela
    /// e num nível acima das janelas do app em foco.
    private func checkWindowOrder(front: String) {
        let ours = model.overlay.panel.windowNumber
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            check("Lista de janelas do sistema", false); return
        }
        let frontPID = NSRunningApplication.runningApplications(withBundleIdentifier: front).first?.processIdentifier ?? -1
        let mine = list.first { ($0[kCGWindowNumber as String] as? Int) == ours }
        let theirs = list.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == frontPID }
        let myLayer = mine?[kCGWindowLayer as String] as? Int ?? -1
        let theirLayers = theirs.compactMap { $0[kCGWindowLayer as String] as? Int }
        let myIndex = list.firstIndex { ($0[kCGWindowNumber as String] as? Int) == ours } ?? Int.max
        let theirFirst = list.firstIndex { ($0[kCGWindowOwnerPID as String] as? Int32) == frontPID } ?? Int.max
        check("Sobreposição listada na tela acima das janelas de \(front)",
              mine != nil && theirLayers.allSatisfy { $0 < myLayer } && myIndex < theirFirst,
              "camada da sobreposição \(myLayer); camadas de \(front): \(theirLayers); ordem \(myIndex) vs \(theirFirst)")
    }

    private func snapshot(_ view: NSView, _ name: String) {
        guard let dir = snapshotDirectory, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(name + ".png"))
    }

    private func snapshots() async {
        let root = model.overlay.root
        model.selectScript(model.store.scripts.first?.id)
        await wait(0.3)
        model.engine.setOffset(90)
        model.setMode(.adjust)
        await wait(0.5)
        snapshot(root, "sobreposicao-ajustar")
        model.setMode(.read)
        await wait(0.3)
        snapshot(root, "sobreposicao-ler")
        model.store.preferences.backgroundOpacity = 0
        model.store.preferences.mirror = true
        await wait(0.3)
        snapshot(root, "sobreposicao-ler-transparente-espelhada")
        model.store.preferences.mirror = false
        model.store.preferences.backgroundOpacity = 0.25
        model.setMode(.adjust)
        model.windows.showEditor()
        await wait(1.0)
        if let v = model.windows.editorWindow?.contentView { snapshot(v, "editor") }
        model.windows.showSettings()
        await wait(1.0)
        if let v = NSApp.keyWindow?.contentView { snapshot(v, "ajustes") }
    }

    /// Simula um arrasto real: os eventos entram na fila do app (como os do mouse) e são
    /// lidos em ordem pelo laço de acompanhamento da alça.
    private func drag(in panel: NSPanel, from start: NSPoint, by delta: NSPoint) async {
        func ev(_ type: NSEvent.EventType, _ p: NSPoint) -> NSEvent? {
            NSEvent.mouseEvent(with: type, location: p, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
        }
        panel.contentView?.layoutSubtreeIfNeeded()
        // Todos os eventos são criados em relação à posição inicial da janela, como pontos fixos na tela.
        var events = [ev(.leftMouseDown, start)]
        for i in 1...5 {
            events.append(ev(.leftMouseDragged, NSPoint(x: start.x + delta.x * CGFloat(i) / 5, y: start.y + delta.y * CGFloat(i) / 5)))
        }
        events.append(ev(.leftMouseUp, NSPoint(x: start.x + delta.x, y: start.y + delta.y)))
        for e in events.compactMap({ $0 }) { NSApp.postEvent(e, atStart: false) }
        await wait(0.4)
    }

    private func checkResizeHandles() async {
        let panel = model.overlay.panel
        model.setMode(.adjust)
        let original = NSRect(x: 200, y: 300, width: 800, height: 300)
        panel.setFrame(original, display: true)
        await wait(0.3)

        // Canto inferior direito (coordenadas da janela: origem embaixo à esquerda).
        await drag(in: panel, from: NSPoint(x: original.width - 6, y: 6), by: NSPoint(x: 120, y: -80))
        await wait(0.2)
        var f = panel.frame
        check("Redimensionar pelo canto inferior direito", abs(f.width - 920) < 2 && abs(f.height - 380) < 2 && abs(f.maxY - original.maxY) < 2,
              "\(NSStringFromRect(original)) → \(NSStringFromRect(f))")

        // Borda esquerda.
        let before = panel.frame
        await drag(in: panel, from: NSPoint(x: 5, y: before.height / 2), by: NSPoint(x: -100, y: 0))
        await wait(0.2)
        f = panel.frame
        check("Redimensionar pela borda esquerda", abs(f.width - (before.width + 100)) < 2 && abs(f.maxX - before.maxX) < 2,
              "\(NSStringFromRect(before)) → \(NSStringFromRect(f))")

        // Borda superior.
        let b2 = panel.frame
        await drag(in: panel, from: NSPoint(x: b2.width / 2, y: b2.height - 5), by: NSPoint(x: 0, y: 50))
        await wait(0.2)
        f = panel.frame
        check("Redimensionar pela borda superior", abs(f.height - (b2.height + 50)) < 2 && abs(f.minY - b2.minY) < 2,
              "\(NSStringFromRect(b2)) → \(NSStringFromRect(f))")

        // Tamanho mínimo respeitado.
        await drag(in: panel, from: NSPoint(x: panel.frame.width - 6, y: 6), by: NSPoint(x: -5000, y: 5000))
        await wait(0.2)
        check("Tamanho mínimo respeitado", panel.frame.width >= panel.minSize.width && panel.frame.height >= panel.minSize.height,
              NSStringFromRect(panel.frame))

        // Alternativa pelos Ajustes.
        model.overlay.resize(width: 700, height: 250)
        check("Redimensionar pelos Ajustes (largura/altura)", panel.frame.width == 700 && panel.frame.height == 250, NSStringFromRect(panel.frame))

        // Cantos e bordas não podem ser 100% transparentes, senão o clique atravessa a janela.
        let root = model.overlay.root
        root.layoutSubtreeIfNeeded()
        if let rep = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
            root.cacheDisplay(in: root.bounds, to: rep)
            let pts = [(0, 0), (rep.pixelsWide - 1, 0), (0, rep.pixelsHigh - 1), (rep.pixelsWide - 1, rep.pixelsHigh - 1),
                       (rep.pixelsWide / 2, 0), (0, rep.pixelsHigh / 2)]
            let alphas = pts.map { rep.colorAt(x: $0.0, y: $0.1)?.alphaComponent ?? 0 }
            check("Cantos e bordas recebem cliques no modo Ajustar (não transparentes)", alphas.allSatisfy { $0 > 0 },
                  "alfa: " + alphas.map { String(format: "%.3f", $0) }.joined(separator: ", "))
        }
        panel.setFrame(original, display: true)
        model.overlay.saveFrame()
    }

    private func write() {
        let summary: [String: Any] = [
            "total": results.count,
            "falhas": results.filter { ($0["ok"] as? Bool) != true }.count,
            "resultados": results,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: output)
        }
    }
}
