import Foundation

// MARK: - Roteiro

public struct Script: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String, body: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    public static let sample = Script(
        title: "Exemplo — como usar o teleprompter",
        body: """
        Olá! Este é um roteiro de exemplo.

        Ele serve para você testar a leitura antes de gravar.

        Posicione esta janela perto da câmera, ajuste o tamanho da letra e a velocidade, e clique em “Ler”.

        No modo Ler, os cliques atravessam o texto e chegam ao OBS, ou a qualquer outro aplicativo que estiver atrás.

        Para voltar ao modo Ajustar, use o ícone na barra de menus ou o atalho Control + Option + L.

        Acentuação, cedilha e pontuação aparecem normalmente: ação, coração, você, até já.

        Quando terminar, apague este exemplo ou crie um roteiro novo no editor.

        Boa gravação!
        """
    )
}

// MARK: - Cor

public struct RGBAColor: Codable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
}

// MARK: - Opções

public enum FontWeightOption: String, Codable, CaseIterable, Identifiable {
    case regular, medium, semibold, bold, heavy
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .regular: return "Regular"
        case .medium: return "Médio"
        case .semibold: return "Seminegrito"
        case .bold: return "Negrito"
        case .heavy: return "Extra-negrito"
        }
    }
}

public enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable {
    case left, center
    public var id: String { rawValue }
    public var label: String { self == .left ? "À esquerda" : "Centralizado" }
}

public enum CountdownOption: Int, Codable, CaseIterable, Identifiable {
    case off = 0, three = 3, five = 5, ten = 10
    public var id: Int { rawValue }
    public var label: String { self == .off ? "Desligada" : "\(rawValue) segundos" }
}

public enum HotkeyAction: String, Codable, CaseIterable, Identifiable {
    case playPause, faster, slower, toggleOverlay, toggleMode, rewind
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .playPause: return "Iniciar / pausar"
        case .faster: return "Aumentar velocidade"
        case .slower: return "Diminuir velocidade"
        case .toggleOverlay: return "Mostrar / esconder sobreposição"
        case .toggleMode: return "Alternar Ajustar / Ler"
        case .rewind: return "Voltar ao começo"
        }
    }
}

/// Posição salva da sobreposição, em coordenadas globais do AppKit (origem no canto inferior esquerdo da tela principal).
public struct SavedFrame: Codable, Equatable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public init(_ rect: CGRect) {
        self.init(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
    }
    public var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

// MARK: - Preferências

public struct Preferences: Codable, Equatable {
    // Texto
    public var fontSize: Double = 44
    public var fontWeight: FontWeightOption = .semibold
    public var textColor: RGBAColor = .white
    public var textOpacity: Double = 1
    public var lineSpacing: Double = 1.25
    public var readingWidth: Double = 0.9
    public var alignment: TextAlignmentOption = .left
    public var outline: Bool = true
    public var shadow: Bool = true
    public var mirror: Bool = false

    // Fundo e foco
    public var backgroundColor: RGBAColor = .black
    public var backgroundOpacity: Double = 0.25
    public var topMargin: Double = 0
    public var focusPosition: Double = 0.3
    public var showFocusArea: Bool = true

    // Rolagem
    public var speed: Double = 40
    public var countdown: CountdownOption = .three

    // Janela e captura
    public var overlayFrame: SavedFrame? = nil
    public var overlayVisible: Bool = true
    public var excludeFromCapture: Bool = false

    // Roteiro em leitura
    public var selectedScriptID: UUID? = nil

    // Atalhos globais (chave = HotkeyAction.rawValue)
    public var hotkeys: [String: KeyCombo] = KeyCombo.defaults

    public init() {}

    public static let speedRange: ClosedRange<Double> = 5...400
    public static let speedStep: Double = 5
    public static let fontSizeRange: ClosedRange<Double> = 16...160

    public func hotkey(for action: HotkeyAction) -> KeyCombo? { hotkeys[action.rawValue] }

    // Decodificação tolerante: campos ausentes (versões antigas do arquivo) recebem o valor padrão.
    private enum CodingKeys: String, CodingKey {
        case fontSize, fontWeight, textColor, textOpacity, lineSpacing, readingWidth, alignment, outline, shadow, mirror
        case backgroundColor, backgroundOpacity, topMargin, focusPosition, showFocusArea
        case speed, countdown, overlayFrame, overlayVisible, excludeFromCapture, selectedScriptID, hotkeys
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        fontSize = v(.fontSize, d.fontSize)
        fontWeight = v(.fontWeight, d.fontWeight)
        textColor = v(.textColor, d.textColor)
        textOpacity = v(.textOpacity, d.textOpacity)
        lineSpacing = v(.lineSpacing, d.lineSpacing)
        readingWidth = v(.readingWidth, d.readingWidth)
        alignment = v(.alignment, d.alignment)
        outline = v(.outline, d.outline)
        shadow = v(.shadow, d.shadow)
        mirror = v(.mirror, d.mirror)
        backgroundColor = v(.backgroundColor, d.backgroundColor)
        backgroundOpacity = v(.backgroundOpacity, d.backgroundOpacity)
        topMargin = v(.topMargin, d.topMargin)
        focusPosition = v(.focusPosition, d.focusPosition)
        showFocusArea = v(.showFocusArea, d.showFocusArea)
        speed = v(.speed, d.speed)
        countdown = v(.countdown, d.countdown)
        overlayFrame = v(.overlayFrame, d.overlayFrame)
        overlayVisible = v(.overlayVisible, d.overlayVisible)
        excludeFromCapture = v(.excludeFromCapture, d.excludeFromCapture)
        selectedScriptID = v(.selectedScriptID, d.selectedScriptID)
        var keys = v(.hotkeys, d.hotkeys)
        for action in HotkeyAction.allCases where keys[action.rawValue] == nil {
            keys[action.rawValue] = KeyCombo.defaults[action.rawValue]
        }
        // Migra os dois padrões antigos sem sobrescrever atalhos personalizados.
        if keys[HotkeyAction.playPause.rawValue] == KeyCombo(keyCode: 35, modifiers: KeyCombo.control | KeyCombo.option) {
            keys[HotkeyAction.playPause.rawValue] = KeyCombo.defaults[HotkeyAction.playPause.rawValue]
        }
        if keys[HotkeyAction.rewind.rawValue] == KeyCombo(keyCode: 15, modifiers: KeyCombo.control | KeyCombo.option) {
            keys[HotkeyAction.rewind.rawValue] = KeyCombo.defaults[HotkeyAction.rewind.rawValue]
        }
        hotkeys = keys
        speed = min(max(speed, Self.speedRange.lowerBound), Self.speedRange.upperBound)
        fontSize = min(max(fontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
    }
}
