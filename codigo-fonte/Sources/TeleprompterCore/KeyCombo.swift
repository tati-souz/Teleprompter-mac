import Foundation

/// Combinação de teclas para atalho global.
/// `keyCode` é o código virtual da tecla (posição física, igual à API Carbon `kVK_*`);
/// `modifiers` usa as máscaras da Carbon (cmdKey, shiftKey, optionKey, controlKey).
public struct KeyCombo: Codable, Equatable, Hashable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Máscaras Carbon (Events.h) — repetidas aqui para o núcleo não depender da Carbon.
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12

    /// F7 e F8 podem ser usadas sozinhas; demais teclas exigem ⌘, ⌃ ou ⌥.
    public var isAllowedGlobalShortcut: Bool {
        (modifiers == 0 && (keyCode == 98 || keyCode == 100)) ||
        modifiers & (Self.command | Self.control | Self.option) != 0
    }

    public var displayString: String {
        var s = ""
        if modifiers & Self.control != 0 { s += "⌃" }
        if modifiers & Self.option != 0 { s += "⌥" }
        if modifiers & Self.shift != 0 { s += "⇧" }
        if modifiers & Self.command != 0 { s += "⌘" }
        return s + Self.keyName(keyCode)
    }

    public static let defaults: [String: KeyCombo] = [
        HotkeyAction.playPause.rawValue: KeyCombo(keyCode: 100, modifiers: 0),                    // F8
        HotkeyAction.faster.rawValue: KeyCombo(keyCode: 24, modifiers: control | option),         // ⌃⌥=
        HotkeyAction.slower.rawValue: KeyCombo(keyCode: 27, modifiers: control | option),         // ⌃⌥-
        HotkeyAction.toggleOverlay.rawValue: KeyCombo(keyCode: 4, modifiers: control | option),   // ⌃⌥H
        HotkeyAction.toggleMode.rawValue: KeyCombo(keyCode: 37, modifiers: control | option),     // ⌃⌥L
        HotkeyAction.rewind.rawValue: KeyCombo(keyCode: 98, modifiers: 0),                       // F7
    ]

    private static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
        12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4",
        22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
        32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Espaço", 50: "`",
        51: "⌫", 53: "Esc", 115: "Home", 116: "PgUp", 117: "⌦", 119: "End", 121: "PgDn",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
    ]

    public static func keyName(_ code: UInt32) -> String {
        names[code] ?? "Tecla \(code)"
    }

    /// Ações que compartilham a mesma combinação.
    public static func duplicates(in map: [String: KeyCombo]) -> Set<String> {
        var seen: [KeyCombo: String] = [:]
        var dup = Set<String>()
        for key in map.keys.sorted() {
            guard let combo = map[key] else { continue }
            if let other = seen[combo] {
                dup.insert(other)
                dup.insert(key)
            } else {
                seen[combo] = key
            }
        }
        return dup
    }
}
