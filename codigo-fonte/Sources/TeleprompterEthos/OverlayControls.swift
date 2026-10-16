import SwiftUI
import TeleprompterCore

/// Barra de controles exibida na sobreposição apenas no modo Ajustar.
struct OverlayControls: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: ScrollEngine
    @ObservedObject var store: Store

    var body: some View {
        HStack(spacing: 10) {
            Button { model.togglePlayPause() } label: {
                Image(systemName: engine.state.isRunning ? "pause.fill" : "play.fill").frame(width: 18)
            }
            .help(engine.state.isRunning ? "Pausar" : "Iniciar / retomar")

            Button { model.rewind() } label: { Image(systemName: "backward.end.fill") }
                .help("Voltar ao começo")

            Divider().frame(height: 18)

            Button { model.slower() } label: { Image(systemName: "tortoise.fill") }
                .help("Diminuir velocidade (−\(Int(Preferences.speedStep)) pt/s)")
            Slider(value: $engine.speed, in: Preferences.speedRange)
                .frame(minWidth: 70, maxWidth: 150)
                .help("Velocidade de rolagem")
            Button { model.faster() } label: { Image(systemName: "hare.fill") }
                .help("Aumentar velocidade (+\(Int(Preferences.speedStep)) pt/s)")
            Text("\(Int(engine.speed.rounded())) pt/s")
                .monospacedDigit()
                .frame(width: 58, alignment: .leading)
                .help("Pontos por segundo: quanto o texto sobe a cada segundo")

            Divider().frame(height: 18)

            Button { model.changeFontSize(by: -4) } label: { Image(systemName: "textformat.size.smaller") }
                .help("Diminuir letra")
            Button { model.changeFontSize(by: 4) } label: { Image(systemName: "textformat.size.larger") }
                .help("Aumentar letra")

            Menu {
                ForEach(store.scripts) { s in
                    Button {
                        model.selectScript(s.id)
                    } label: {
                        if s.id == store.selectedScript?.id { Label(s.title, systemImage: "checkmark") } else { Text(s.title) }
                    }
                }
            } label: {
                Image(systemName: "doc.text")
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Escolher roteiro")

            Spacer(minLength: 4)

            Button { model.windows.showSettings() } label: { Image(systemName: "slider.horizontal.3") }
                .help("Ajustes de aparência e atalhos")
            Button { model.hideOverlay() } label: { Image(systemName: "eye.slash") }
                .help("Esconder sobreposição (o app continua no menu)")
            Button { model.setMode(.read) } label: {
                Text("Ler").fontWeight(.semibold).padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .help("Modo Ler: esconde controles e deixa os cliques passarem. Volte pelo menu ou com \(model.store.preferences.hotkey(for: .toggleMode)?.displayString ?? "o atalho")")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.12).opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
