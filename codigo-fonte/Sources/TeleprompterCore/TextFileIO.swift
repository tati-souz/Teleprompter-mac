import Foundation

/// Importação e exportação de arquivos .txt.
public enum TextFileIO {
    public struct ImportResult: Equatable {
        public var text: String
        /// Nome da codificação usada quando o arquivo não estava em UTF-8 (para avisar a pessoa).
        public var fallbackEncoding: String?
    }

    public enum IOError: LocalizedError {
        case unreadable
        public var errorDescription: String? {
            "O arquivo não pôde ser lido como texto. Salve-o como “Texto simples (UTF-8)” e tente de novo."
        }
    }

    /// Lê texto, preferindo UTF-8 (com ou sem BOM). Normaliza quebras de linha para `\n`.
    public static func read(_ url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> ImportResult {
        var bytes = data
        var fallback: String?
        var text: String?

        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes = bytes.dropFirst(3) }

        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16)
            fallback = "UTF-16"
        } else if let s = String(data: bytes, encoding: .utf8) {
            text = s
        } else if let s = String(data: bytes, encoding: .windowsCP1252) {
            text = s
            fallback = "Windows-1252 (Latin-1)"
        } else if let s = String(data: bytes, encoding: .macOSRoman) {
            text = s
            fallback = "Mac OS Roman"
        }

        guard var result = text else { throw IOError.unreadable }
        if result.hasPrefix("\u{FEFF}") { result.removeFirst() }
        result = normalizeLineEndings(result)
        return ImportResult(text: result, fallbackEncoding: fallback)
    }

    public static func normalizeLineEndings(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    /// Grava em UTF-8, sem BOM, de forma atômica.
    public static func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    /// Nome de arquivo seguro a partir do título do roteiro.
    public static func fileName(for title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty ? "Roteiro" : cleaned) + ".txt"
    }

    /// Título sugerido a partir do nome do arquivo importado.
    public static func title(from url: URL) -> String {
        let t = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "Roteiro importado" : t
    }
}
