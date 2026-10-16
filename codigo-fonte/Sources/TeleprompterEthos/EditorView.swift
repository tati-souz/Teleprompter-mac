import SwiftUI
import TeleprompterCore

/// Janela do editor: lista de roteiros à esquerda e texto à direita.
struct EditorView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: Store
    @ObservedObject var engine: ScrollEngine

    @State private var renameTarget: Script?
    @State private var renameText = ""
    @State private var deleteTarget: Script?

    private var selection: Binding<UUID?> {
        Binding(get: { store.selectedScript?.id }, set: { model.selectScript($0) })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(store.scripts) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title.isEmpty ? "Sem título" : s.title).lineLimit(1)
                        Text("\(s.wordCount) palavras · \(s.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(s.id)
                    .contextMenu {
                        Button("Renomear…") { beginRename(s) }
                        Button("Exportar como .txt…") {
                            model.selectScript(s.id)
                            model.exportSelected(from: model.windows.editorWindow)
                        }
                        Divider()
                        Button("Excluir…", role: .destructive) { deleteTarget = s }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 360)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button { model.newScript() } label: { Label("Novo", systemImage: "plus") }
                    Button { model.importScripts(from: model.windows.editorWindow) } label: { Label("Importar", systemImage: "square.and.arrow.down") }
                    Spacer()
                    Button(role: .destructive) { deleteTarget = store.selectedScript } label: { Image(systemName: "trash") }
                        .disabled(store.selectedScript == nil)
                        .help("Excluir roteiro selecionado")
                }
                .buttonStyle(.borderless)
                .padding(10)
            }
        } detail: {
            VStack(spacing: 0) {
                if let err = store.lastError {
                    ErrorBanner(message: err, retry: model.retrySave, dismiss: store.dismissError)
                }
                if let script = store.selectedScript {
                    ScriptDetail(script: script, store: store, model: model, engine: engine,
                                 rename: { beginRename(script) })
                        .id(script.id)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Nenhum roteiro").font(.title3)
                        Text("Crie um roteiro novo ou importe um arquivo .txt.").foregroundStyle(.secondary)
                        Button("Novo roteiro") { model.newScript() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .alert("Renomear roteiro", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField("Título", text: $renameText)
            Button("Renomear") {
                if let t = renameTarget { store.rename(t.id, to: renameText) }
                renameTarget = nil
            }
            Button("Cancelar", role: .cancel) { renameTarget = nil }
        }
        .alert("Excluir “\(deleteTarget?.title ?? "")”?",
               isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("Excluir", role: .destructive) {
                if let t = deleteTarget { store.delete(t.id) }
                deleteTarget = nil
            }
            Button("Cancelar", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("O roteiro será apagado deste aplicativo. Esta ação não pode ser desfeita. Se quiser guardar uma cópia, exporte-o como .txt antes.")
        }
    }

    private func beginRename(_ s: Script) {
        renameText = s.title
        renameTarget = s
    }
}

private struct ScriptDetail: View {
    let script: Script
    @ObservedObject var store: Store
    @ObservedObject var model: AppModel
    @ObservedObject var engine: ScrollEngine
    let rename: () -> Void

    private var body_: Binding<String> {
        Binding(get: { store.scripts.first { $0.id == script.id }?.body ?? "" },
                set: { store.updateBody(script.id, body: $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(script.title.isEmpty ? "Sem título" : script.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                Button("Renomear", action: rename).buttonStyle(.link)
                Spacer()
                Text("\(script.wordCount) palavras · \(script.body.count) caracteres")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            TextEditor(text: body_)
                .font(.system(size: 15))
                .lineSpacing(3)
                .padding(.horizontal, 10)

            Divider()
            HStack(spacing: 10) {
                Button { model.showOverlay(); model.togglePlayPause() } label: {
                    Label(model.playPauseTitle, systemImage: engine.state.isRunning ? "pause.fill" : "play.fill")
                }
                Button { model.rewind() } label: { Image(systemName: "backward.end.fill") }
                    .help("Voltar ao começo")
                Button { model.toggleOverlay() } label: { Image(systemName: model.overlayVisible ? "eye.slash" : "eye") }
                    .help(model.overlayVisible ? "Esconder sobreposição" : "Mostrar sobreposição")
                Spacer()
                Picker("Modo", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
                    Text("Ajustar").tag(AppModel.Mode.adjust)
                    Text("Ler").tag(AppModel.Mode.read)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Ajustar: mover e redimensionar. Ler: sem controles, cliques atravessam.")
                Button { model.windows.showSettings() } label: { Image(systemName: "slider.horizontal.3") }
                    .help("Ajustes de aparência, rolagem e atalhos")
            }
            .padding(10)
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    let retry: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Tentar salvar de novo", action: retry)
            Button("Fechar aviso", action: dismiss)
        }
        .padding(10)
        .background(Color.orange.opacity(0.15))
    }
}
