import Foundation
import Testing
@testable import TeleprompterCore

@Suite("Rolagem")
struct ScrollEngineTests {
    func engine(speed: Double = 50, countdown: Double = 0, max: Double = 10_000) -> ScrollEngine {
        let e = ScrollEngine(speed: speed, countdownSeconds: countdown)
        e.maxOffset = max
        return e
    }

    @Test func avancaPeloTempoDecorridoIndependenteDaTaxaDeQuadros() {
        let a = engine(), b = engine()
        a.start(); b.start()
        a.tick(now: 0); b.tick(now: 0)
        for i in 1...60 { a.tick(now: Double(i) / 60) }     // 60 Hz
        for i in 1...120 { b.tick(now: Double(i) / 120) }   // 120 Hz
        #expect(abs(a.offset - 50) < 0.001)
        #expect(abs(b.offset - 50) < 0.001)
    }

    @Test func pausarERetomarSemPerderPosicao() {
        let e = engine()
        e.start(); e.tick(now: 0); e.tick(now: 0.1)
        e.pause()
        let p = e.offset
        e.tick(now: 5)                 // tempo passa pausado
        #expect(e.offset == p)
        e.start()
        e.tick(now: 10)                // primeiro quadro após retomar não avança
        #expect(e.offset == p)
        e.tick(now: 10.1)
        #expect(abs(e.offset - (p + 5)) < 0.001)
    }

    @Test func intervaloGrandeNaoGeraSalto() {
        let e = engine()
        e.start(); e.tick(now: 0)
        e.tick(now: 3600)              // ex.: Mac suspenso com a leitura ativa
        #expect(e.offset <= 50 * ScrollEngine.maxFrameInterval + 0.001)
    }

    @Test func paraNoFinal() {
        let e = engine(speed: 100, max: 30)
        e.start(); e.tick(now: 0)
        for i in 1...20 { e.tick(now: Double(i) * 0.05) }
        #expect(e.state == .finished)
        #expect(e.offset == 30)
        e.start()                       // iniciar após o fim recomeça
        #expect(e.offset == 0)
    }

    @Test func contagemRegressiva() {
        let e = engine(countdown: 3)
        e.start(); e.tick(now: 0)
        for i in 1...29 { e.tick(now: Double(i) * 0.1) }
        if case .countingDown = e.state {} else { Issue.record("deveria estar em contagem: \(e.state)") }
        #expect(e.offset == 0)
        for i in 30...40 { e.tick(now: Double(i) * 0.1) }
        #expect(e.state == .playing)
        #expect(e.offset > 0)
    }

    @Test func velocidadeLimitadaEAjustavelDuranteLeitura() {
        let e = engine()
        e.speed = 10_000
        #expect(e.speed == 400)
        e.speed = 0
        #expect(e.speed == 5)
        e.speed = 100
        e.start(); e.tick(now: 0); e.tick(now: 0.1)
        e.speed = 200
        e.tick(now: 0.2)
        #expect(abs(e.offset - 30) < 0.001)
    }

    @Test func reposicionamentoManualPausaELimita() {
        let e = engine(max: 500)
        e.start(); e.tick(now: 0); e.tick(now: 0.1)
        e.setOffset(9999)
        #expect(e.state == .paused)
        #expect(e.offset == 500)
        e.setOffset(-10)
        #expect(e.offset == 0)
    }

    @Test func voltarAoComeco() {
        let e = engine()
        e.start(); e.tick(now: 0); e.tick(now: 0.1)
        e.rewind()
        #expect(e.offset == 0)
        #expect(e.state == .idle)
    }
}

@Suite("Persistência")
struct StoreTests {
    func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("tp-tests-\(UUID().uuidString)")
        return d
    }

    @Test func primeiroUsoTemExemploESalvaERestaura() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let s1 = Store(directory: dir)
        #expect(s1.scripts.count == 1)
        #expect(s1.scripts[0].title == Script.sample.title)

        let novo = s1.addScript(title: "Coração", body: "Linha 1 — ação\nLinha 2: você, já, pôr.")
        s1.preferences.speed = 77
        s1.preferences.fontSize = 60
        s1.rename(novo.id, to: "Coração e razão")
        try s1.saveNow()

        let s2 = Store(directory: dir)
        #expect(s2.scripts.count == 2)
        #expect(s2.scripts[1].title == "Coração e razão")
        #expect(s2.scripts[1].body == "Linha 1 — ação\nLinha 2: você, já, pôr.")
        #expect(s2.preferences.speed == 77)
        #expect(s2.preferences.fontSize == 60)
        #expect(s2.preferences.selectedScriptID == novo.id)
        #expect(s2.lastError == nil)
    }

    @Test func excluirAjustaSelecao() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let s = Store(directory: dir)
        let a = s.addScript(title: "A")
        _ = s.addScript(title: "B")
        s.preferences.selectedScriptID = a.id
        s.delete(a.id)
        #expect(!s.scripts.contains { $0.id == a.id })
        #expect(s.preferences.selectedScriptID != nil)
    }

    @Test func titulosRepetidosGanhamNumero() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let s = Store(directory: dir)
        let a = s.addScript()
        let b = s.addScript()
        #expect(a.title == "Novo roteiro")
        #expect(b.title == "Novo roteiro 2")
    }

    @Test func arquivoDanificadoGeraAvisoEBackup() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ isto não é json".utf8).write(to: dir.appendingPathComponent("roteiros.json"))
        let s = Store(directory: dir)
        #expect(s.lastError != nil)
        #expect(!s.scripts.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains { $0.contains("danificado") })
    }

    @Test func falhaAoSalvarInformaMensagemClara() throws {
        let dir = tempDir()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }
        let s = Store(directory: dir)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path) // só leitura
        s.preferences.speed = 99
        #expect(throws: (any Error).self) { try s.saveNow() }
        #expect(s.lastError?.contains("Não foi possível salvar") == true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
        try s.saveNow()
        #expect(s.lastError == nil)
    }

    @Test func preferenciasAntigasSemCamposNovos() throws {
        let json = #"{"fontSize": 50, "speed": 9999}"#
        let p = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        #expect(p.fontSize == 50)
        #expect(p.speed == 400)
        #expect(p.hotkeys.count == HotkeyAction.allCases.count)
        #expect(p.countdown == .three)
    }
}

@Suite("Arquivos .txt")
struct TextFileIOTests {
    let sample = "Título: Prudência\n\nA virtude não nasce do impulso — nasce do hábito.\nAção, coração, você, já, pôr, ç, ã, õ, ü.\n"

    @Test func ida_e_volta_utf8_preserva_acentos_e_quebras() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tp-\(UUID()).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try TextFileIO.write(sample, to: url)
        let raw = try Data(contentsOf: url)
        #expect(!raw.starts(with: [0xEF, 0xBB, 0xBF]))      // sem BOM
        #expect(String(data: raw, encoding: .utf8) == sample)
        let back = try TextFileIO.read(url)
        #expect(back.text == sample)
        #expect(back.fallbackEncoding == nil)
    }

    @Test func utf8ComBOMeCRLF() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("Olá\r\nmundo\r\rfim".utf8))
        let r = try TextFileIO.decode(data)
        #expect(r.text == "Olá\nmundo\n\nfim")
    }

    @Test func latin1ComAviso() throws {
        let data = "Ação e coração".data(using: .windowsCP1252)!
        let r = try TextFileIO.decode(data)
        #expect(r.text == "Ação e coração")
        #expect(r.fallbackEncoding != nil)
    }

    @Test func utf16() throws {
        let data = "Você já leu?".data(using: .utf16)!   // inclui BOM
        let r = try TextFileIO.decode(data)
        #expect(r.text == "Você já leu?")
    }

    @Test func nomesDeArquivo() {
        #expect(TextFileIO.fileName(for: "Prudência: aula 1/2") == "Prudência- aula 1-2.txt")
        #expect(TextFileIO.fileName(for: "   ") == "Roteiro.txt")
        #expect(TextFileIO.title(from: URL(fileURLWithPath: "/tmp/Coração.txt")) == "Coração")
    }
}

@Suite("Telas e atalhos")
struct GeometryAndKeysTests {
    let main = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let external = CGRect(x: 1440, y: 0, width: 1920, height: 1055)

    @Test func mantemPosicaoValida() {
        let f = CGRect(x: 1600, y: 600, width: 800, height: 300)
        #expect(ScreenGeometry.validatedFrame(saved: f, screens: [main, external], fallback: .zero) == f)
    }

    @Test func monitorDesconectadoVoltaParaTelaVisivel() {
        let f = CGRect(x: 1600, y: 600, width: 800, height: 300)  // estava no monitor externo
        let fallback = ScreenGeometry.defaultFrame(in: main)
        let r = ScreenGeometry.validatedFrame(saved: f, screens: [main], fallback: fallback)
        #expect(r == fallback)
        #expect(main.contains(r))
    }

    @Test func parcialmenteForaEhTrazidaParaDentro() {
        let f = CGRect(x: 1300, y: 700, width: 800, height: 300)
        let r = ScreenGeometry.validatedFrame(saved: f, screens: [main], fallback: .zero)
        #expect(main.contains(r))
        #expect(r.size == f.size)
    }

    @Test func maiorQueATelaEhReduzida() {
        let f = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let r = ScreenGeometry.validatedFrame(saved: f, screens: [main], fallback: .zero)
        #expect(main.contains(r))
    }

    @Test func atalhosPadraoValidosESemDuplicatas() {
        for (_, combo) in KeyCombo.defaults { #expect(combo.isAllowedGlobalShortcut) }
        #expect(KeyCombo.duplicates(in: KeyCombo.defaults).isEmpty)
        #expect(KeyCombo.defaults[HotkeyAction.toggleMode.rawValue]?.displayString == "⌃⌥L")
    }

    @Test func teclasSimplesNaoSaoAceitas() {
        #expect(!KeyCombo(keyCode: 49, modifiers: 0).isAllowedGlobalShortcut)                 // Espaço
        #expect(!KeyCombo(keyCode: 126, modifiers: KeyCombo.shift).isAllowedGlobalShortcut)   // ⇧↑
        #expect(KeyCombo(keyCode: 49, modifiers: KeyCombo.control).isAllowedGlobalShortcut)
    }

    @Test func detectaDuplicatas() {
        var map = KeyCombo.defaults
        map[HotkeyAction.rewind.rawValue] = map[HotkeyAction.playPause.rawValue]
        #expect(KeyCombo.duplicates(in: map) == [HotkeyAction.rewind.rawValue, HotkeyAction.playPause.rawValue])
    }
}

@Suite("Atalhos F7 e F8")
struct FunctionKeyTests {
    @Test func functionKeysAndTypingProtection() {
        #expect(KeyCombo.defaults[HotkeyAction.playPause.rawValue] == KeyCombo(keyCode: 100, modifiers: 0))
        #expect(KeyCombo.defaults[HotkeyAction.rewind.rawValue] == KeyCombo(keyCode: 98, modifiers: 0))
        #expect(KeyCombo(keyCode: 100, modifiers: 0).isAllowedGlobalShortcut)
        #expect(KeyCombo(keyCode: 98, modifiers: 0).isAllowedGlobalShortcut)
        #expect(!KeyCombo(keyCode: 15, modifiers: 0).isAllowedGlobalShortcut)
    }
    @Test func migratesOldDefaultsAndPreservesCustomShortcuts() throws {
        let old = Data(#"{"hotkeys":{"playPause":{"keyCode":35,"modifiers":6144},"rewind":{"keyCode":15,"modifiers":6144}}}"#.utf8)
        let migrated = try JSONDecoder().decode(Preferences.self, from: old)
        #expect(migrated.hotkey(for: .playPause)?.displayString == "F8")
        #expect(migrated.hotkey(for: .rewind)?.displayString == "F7")
        var custom = Preferences()
        custom.hotkeys[HotkeyAction.playPause.rawValue] = KeyCombo(keyCode: 40, modifiers: KeyCombo.command)
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(custom))
        #expect(restored.hotkeys == custom.hotkeys)
    }
}
