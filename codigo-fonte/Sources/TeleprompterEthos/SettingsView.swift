import SwiftUI
import AppKit
import TeleprompterCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: Store
    @ObservedObject var engine: ScrollEngine

    var body: some View {
        TabView {
            textTab.tabItem { Label("Texto", systemImage: "textformat") }
            backgroundTab.tabItem { Label("Fundo e foco", systemImage: "rectangle.dashed") }
            scrollTab.tabItem { Label("Rolagem", systemImage: "arrow.up.and.down.text.horizontal") }
            hotkeysTab.tabItem { Label("Atalhos", systemImage: "keyboard") }
            captureTab.tabItem { Label("Gravação", systemImage: "record.circle") }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 460)
    }

    // MARK: Texto

    private var textTab: some View {
        Form {
            LabeledSlider("Tamanho da letra", value: $store.preferences.fontSize, range: Preferences.fontSizeRange, step: 1) { "\(Int($0)) pt" }
            Picker("Peso", selection: $store.preferences.fontWeight) {
                ForEach(FontWeightOption.allCases) { Text($0.label).tag($0) }
            }
            ColorPicker("Cor do texto", selection: colorBinding(\.textColor), supportsOpacity: false)
            LabeledSlider("Opacidade do texto", value: $store.preferences.textOpacity, range: 0.2...1, step: 0.05) { "\(Int($0 * 100))%" }
            LabeledSlider("Espaçamento entre linhas", value: $store.preferences.lineSpacing, range: 0.9...2.5, step: 0.05) { String(format: "%.2f×", $0) }
            LabeledSlider("Largura de leitura", value: $store.preferences.readingWidth, range: 0.3...1, step: 0.01) { "\(Int($0 * 100))% da janela" }
            Picker("Alinhamento", selection: $store.preferences.alignment) {
                ForEach(TextAlignmentOption.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Contorno discreto (legível sobre áreas claras)", isOn: $store.preferences.outline)
            Toggle("Sombra", isOn: $store.preferences.shadow)
            Toggle("Espelhar o texto horizontalmente (para vidro de teleprompter)", isOn: $store.preferences.mirror)
            Text("O espelhamento vale só para o texto; os controles continuam legíveis.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    // MARK: Fundo e foco

    private var backgroundTab: some View {
        Form {
            Section {
                LabeledSlider("Opacidade do fundo", value: $store.preferences.backgroundOpacity, range: 0...1, step: 0.01) {
                    $0 == 0 ? "Transparente" : "\(Int($0 * 100))%"
                }
                ColorPicker("Cor do fundo", selection: colorBinding(\.backgroundColor), supportsOpacity: false)
                Text("A opacidade do fundo é independente da do texto: com fundo transparente as letras continuam totalmente visíveis. No modo Ajustar sempre aparece um véu leve para que a janela possa ser arrastada.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Tamanho da sobreposição") {
                LabeledSlider("Largura", value: frameBinding(\.width), range: 460...maxScreen.width, step: 10) { "\(Int($0)) pt" }
                LabeledSlider("Altura", value: frameBinding(\.height), range: 160...maxScreen.height, step: 10) { "\(Int($0)) pt" }
                Button("Restaurar tamanho e posição padrão") { model.overlay.resetFrame() }
                Text("Também dá para redimensionar arrastando as marcas amarelas nos cantos e no meio das bordas (modo Ajustar).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                LabeledSlider("Margem superior", value: $store.preferences.topMargin, range: 0...400, step: 2) { "\(Int($0)) pt" }
                Text("Espaço vazio no alto da janela (por exemplo, para não cobrir a câmera).")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledSlider("Posição da área de foco", value: $store.preferences.focusPosition, range: 0.1...0.8, step: 0.01) { "\(Int($0 * 100))% da altura" }
                Toggle("Mostrar área de foco", isOn: $store.preferences.showFocusArea)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Rolagem

    private var scrollTab: some View {
        Form {
            LabeledSlider("Velocidade", value: $engine.speed, range: Preferences.speedRange, step: 1) { "\(Int($0)) pt/s" }
            Text("pt/s = pontos por segundo: quanto o texto sobe a cada segundo. Pode ser ajustada durante a leitura (atalhos ou controles da sobreposição), em passos de \(Int(Preferences.speedStep)) pt/s.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Contagem regressiva", selection: $store.preferences.countdown) {
                ForEach(CountdownOption.allCases) { Text($0.label).tag($0) }
            }
            Text("Para reposicionar o texto manualmente, use o modo Ajustar e role com o trackpad ou a roda do mouse sobre a sobreposição (a leitura pausa).")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    // MARK: Atalhos

    private var hotkeysTab: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases) { action in
                    HStack {
                        Text(action.label)
                        Spacer()
                        Button {
                            if model.recordingAction == action { model.endRecording() } else { model.beginRecording(action) }
                        } label: {
                            Text(model.recordingAction == action ? "Pressione a combinação…" :
                                    (store.preferences.hotkey(for: action)?.displayString ?? "—"))
                                .monospaced()
                                .frame(minWidth: 150)
                        }
                    }
                    if let issue = model.hotkeyIssues[action.rawValue] {
                        Label(issue, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                if let msg = model.recordingMessage {
                    Text(msg).font(.caption).foregroundStyle(.orange)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Clique numa combinação e pressione as novas teclas (Esc cancela). F7 e F8 podem ser usadas sozinhas. As demais teclas exigem ⌘, ⌃ ou ⌥.")
                    Text("Padrões: F8 pausa/retoma; F7 volta ao início, parado. Se o teclado acionar mídia, use Fn/🌐 + F7/F8 ou ative as teclas de função padrão nos Ajustes do Sistema. O app não altera essa configuração.")
                    Text("Os atalhos funcionam com o OBS em foco e não exigem permissão de Acessibilidade: o macOS só avisa este app quando a combinação exata é pressionada. Nada do que você digita em outros apps é lido ou registrado.")
                    Text("Conflitos detectados: atalhos repetidos neste app, combinações já registradas por outro app e atalhos ativos do macOS. Atalhos internos de outros apps (ex.: os do próprio OBS) não são detectáveis — se algo não responder, escolha outra combinação.")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Button("Restaurar atalhos padrão") { model.restoreDefaultHotkeys() }
        }
        .formStyle(.grouped)
    }

    // MARK: Gravação

    private var captureTab: some View {
        Form {
            Section("Visível para mim × visível na gravação") {
                Text("A sobreposição sempre aparece na SUA tela. Se ela também aparece no vídeo depende do que o OBS captura:")
                Text("• Captura de janela (só a janela de outro app): normalmente a sobreposição NÃO entra, porque é outra janela.\n• Captura de tela inteira / monitor: normalmente ENTRA, como qualquer janela visível.\n• Câmera: nunca vê a sobreposição.")
                Text("Faça sempre uma gravação curta de teste antes de gravar para valer (veja o README).")
                    .fontWeight(.semibold)
            }
            Section("Experimental") {
                Toggle("Pedir ao macOS para ocultar a sobreposição de capturas de tela", isOn: $store.preferences.excludeFromCapture)
                Text("Usa a opção pública da janela (sharingType = none). Em versões recentes do macOS, capturas pelo ScreenCaptureKit (usado pelo OBS) podem ignorá-la. Não é garantia: confirme com uma gravação de teste.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Utilidades

    private var maxScreen: CGSize {
        let sizes = NSScreen.screens.map(\.visibleFrame.size)
        return CGSize(width: max(800, sizes.map(\.width).max() ?? 1440), height: max(400, sizes.map(\.height).max() ?? 900))
    }

    private func frameBinding(_ kp: KeyPath<SavedFrame, Double>) -> Binding<Double> {
        Binding(
            get: { store.preferences.overlayFrame?[keyPath: kp] ?? Double(model.overlay.panel.frame.width) },
            set: { v in
                if kp == \SavedFrame.width { model.overlay.resize(width: v) } else { model.overlay.resize(height: v) }
            })
    }

    private func colorBinding(_ kp: WritableKeyPath<Preferences, RGBAColor>) -> Binding<Color> {
        Binding(
            get: {
                let c = store.preferences[keyPath: kp]
                return Color(nsColor: NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1))
            },
            set: { newValue in
                let ns = NSColor(newValue).usingColorSpace(.sRGB) ?? .white
                store.preferences[keyPath: kp] = RGBAColor(red: Double(ns.redComponent), green: Double(ns.greenComponent),
                                                           blue: Double(ns.blueComponent))
            })
    }
}

/// Controle deslizante com rótulo e valor numérico.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: Binding(get: { value }, set: { value = (($0 / step).rounded() * step) }), in: range)
                Text(format(value)).monospacedDigit().frame(width: 120, alignment: .trailing)
            }
        }
    }
}
