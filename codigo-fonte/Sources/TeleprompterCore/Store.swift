import Foundation
import Combine

/// Persistência local de roteiros e preferências (JSON em Application Support).
/// Salva automaticamente, com um pequeno atraso, a cada alteração.
public final class Store: ObservableObject {
    @Published public var scripts: [Script]
    @Published public var preferences: Preferences
    /// Mensagem da última falha de leitura/gravação; `nil` quando tudo está salvo.
    @Published public private(set) var lastError: String?

    public let directory: URL
    public var scriptsURL: URL { directory.appendingPathComponent("roteiros.json") }
    public var preferencesURL: URL { directory.appendingPathComponent("preferencias.json") }

    private var cancellables = Set<AnyCancellable>()
    private var pendingSave: DispatchWorkItem?
    private let saveDelay: TimeInterval

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Teleprompter Ethos", isDirectory: true)
    }

    public init(directory: URL = Store.defaultDirectory, saveDelay: TimeInterval = 0.6) {
        self.directory = directory
        self.saveDelay = saveDelay
        self.scripts = []
        self.preferences = Preferences()

        var errors: [String] = []
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            errors.append("Não foi possível criar a pasta de dados (\(directory.path)): \(error.localizedDescription)")
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: scriptsURL.path) {
            do {
                scripts = try Self.decoder.decode([Script].self, from: Data(contentsOf: scriptsURL))
            } catch {
                let backup = Self.backupCorrupt(scriptsURL)
                errors.append("O arquivo de roteiros estava danificado e não pôde ser lido. Uma cópia foi guardada em “\(backup?.lastPathComponent ?? "—")”.")
            }
        } else {
            // Primeiro uso: roteiro de exemplo.
            scripts = [Script.sample]
        }

        if fm.fileExists(atPath: preferencesURL.path) {
            do {
                preferences = try Self.decoder.decode(Preferences.self, from: Data(contentsOf: preferencesURL))
            } catch {
                let backup = Self.backupCorrupt(preferencesURL)
                errors.append("As preferências estavam danificadas e foram restauradas ao padrão. Cópia: “\(backup?.lastPathComponent ?? "—")”.")
            }
        }

        if scripts.isEmpty { scripts = [Script.sample] }
        if preferences.selectedScriptID == nil || !scripts.contains(where: { $0.id == preferences.selectedScriptID }) {
            preferences.selectedScriptID = scripts.first?.id
        }
        // Salva o estado inicial se os arquivos ainda não existiam.
        if !fm.fileExists(atPath: scriptsURL.path) || !fm.fileExists(atPath: preferencesURL.path) {
            do { try saveNow() } catch { errors.append(lastError ?? error.localizedDescription) }
        }
        // Avisos de leitura ficam visíveis até a pessoa fechá-los.
        lastError = errors.isEmpty ? nil : errors.joined(separator: "\n")

        $scripts.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(in: &cancellables)
        $preferences.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(in: &cancellables)
    }

    // MARK: Roteiros

    public var selectedScript: Script? {
        scripts.first { $0.id == preferences.selectedScriptID } ?? scripts.first
    }

    @discardableResult
    public func addScript(title: String = "Novo roteiro", body: String = "") -> Script {
        let s = Script(title: uniqueTitle(title), body: body)
        scripts.append(s)
        preferences.selectedScriptID = s.id
        return s
    }

    public func rename(_ id: UUID, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = scripts.firstIndex(where: { $0.id == id }), !t.isEmpty else { return }
        scripts[i].title = t
        scripts[i].updatedAt = Date()
    }

    public func updateBody(_ id: UUID, body: String) {
        guard let i = scripts.firstIndex(where: { $0.id == id }), scripts[i].body != body else { return }
        scripts[i].body = body
        scripts[i].updatedAt = Date()
    }

    public func delete(_ id: UUID) {
        guard let i = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts.remove(at: i)
        if preferences.selectedScriptID == id {
            preferences.selectedScriptID = scripts.isEmpty ? nil : scripts[min(i, scripts.count - 1)].id
        }
    }

    private func uniqueTitle(_ base: String) -> String {
        let titles = Set(scripts.map(\.title))
        if !titles.contains(base) { return base }
        var n = 2
        while titles.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: Gravação

    public func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do { try self.saveNow() } catch { /* lastError já foi preenchido */ }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDelay, execute: work)
    }

    /// Grava imediatamente (escrita atômica). Em caso de falha, preenche `lastError` e relança o erro.
    public func saveNow() throws {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Self.encoder.encode(scripts).write(to: scriptsURL, options: .atomic)
            try Self.encoder.encode(preferences).write(to: preferencesURL, options: .atomic)
            if lastError != nil { lastError = nil }
        } catch {
            lastError = "Não foi possível salvar em “\(directory.path)”: \(error.localizedDescription). As alterações continuam abertas no aplicativo; tente salvar novamente."
            throw error
        }
    }

    public func dismissError() { lastError = nil }

    // MARK: Utilidades

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static func backupCorrupt(_ url: URL) -> URL? {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dest = url.deletingPathExtension().appendingPathExtension("danificado-\(stamp).json")
        do { try FileManager.default.moveItem(at: url, to: dest); return dest } catch { return nil }
    }
}
