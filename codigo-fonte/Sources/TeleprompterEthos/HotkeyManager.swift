import AppKit
import Carbon.HIToolbox
import TeleprompterCore

/// Atalhos globais via `RegisterEventHotKey` (API pública da Carbon).
///
/// Não requer permissão de Acessibilidade nem de Monitoramento de Entrada: o sistema avisa o app
/// apenas quando a combinação registrada é pressionada. Nada do que é digitado em outros apps é lido.
@MainActor
final class HotkeyManager {
    var onAction: ((HotkeyAction) -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var idToAction: [UInt32: HotkeyAction] = [:]
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x5450_4554 // 'TPET'

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hk = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            guard status == noErr, hk.signature == HotkeyManager.signature else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { manager.fire(hk.id) }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec,
                            Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    private func fire(_ id: UInt32) {
        guard let action = idToAction[id] else { return }
        onAction?(action)
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        idToAction.removeAll()
    }

    /// Registra os atalhos e devolve problemas encontrados por ação (chave = rawValue).
    func register(_ map: [String: KeyCombo]) -> [String: String] {
        unregisterAll()
        var issues: [String: String] = [:]
        let duplicates = KeyCombo.duplicates(in: map)
        let system = Self.enabledSystemShortcuts()

        for (index, action) in HotkeyAction.allCases.enumerated() {
            guard let combo = map[action.rawValue] else { continue }
            if !combo.isAllowedGlobalShortcut {
                issues[action.rawValue] = "Use F7/F8 ou uma combinação com ⌘, ⌃ ou ⌥."
                continue
            }
            if duplicates.contains(action.rawValue) {
                issues[action.rawValue] = "Mesma combinação de outra ação."
                continue
            }
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(combo.keyCode, combo.modifiers,
                                             EventHotKeyID(signature: Self.signature, id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
                idToAction[id] = action
                if system.contains(combo) {
                    issues[action.rawValue] = "Também é um atalho do macOS (Ajustes do Sistema ▸ Teclado ▸ Atalhos). Pode não funcionar."
                }
            } else if status == OSStatus(eventHotKeyExistsErr) {
                issues[action.rawValue] = "Já está em uso por outro aplicativo. Escolha outra combinação."
            } else {
                issues[action.rawValue] = "Não foi possível registrar (erro \(status))."
            }
        }
        return issues
    }

    /// Atalhos do sistema ativos (Ajustes do Sistema ▸ Teclado ▸ Atalhos), lidos das preferências do macOS.
    /// Detecção de conflito de melhor esforço: nem todo atalho de outros apps é visível daqui.
    static func enabledSystemShortcuts() -> Set<KeyCombo> {
        guard let all = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString,
                                                  "com.apple.symbolichotkeys" as CFString) as? [String: Any] else { return [] }
        var result = Set<KeyCombo>()
        for case let entry as [String: Any] in all.values {
            guard (entry["enabled"] as? Bool) == true,
                  let value = entry["value"] as? [String: Any],
                  let params = value["parameters"] as? [Int], params.count >= 3,
                  params[1] != 65535 else { continue }
            let flags = params[2]
            var mods: UInt32 = 0
            if flags & (1 << 17) != 0 { mods |= KeyCombo.shift }
            if flags & (1 << 18) != 0 { mods |= KeyCombo.control }
            if flags & (1 << 19) != 0 { mods |= KeyCombo.option }
            if flags & (1 << 20) != 0 { mods |= KeyCombo.command }
            result.insert(KeyCombo(keyCode: UInt32(params[1]), modifiers: mods))
        }
        return result
    }
}
