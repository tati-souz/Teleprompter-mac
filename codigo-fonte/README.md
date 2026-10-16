# Teleprompter Ethos

Teleprompter nativo para macOS (Swift, SwiftUI e AppKit), em português. O roteiro sobe sozinho numa camada
transparente **por cima do OBS ou de qualquer outro aplicativo**, e você continua vendo e usando o que está atrás.

- Funciona 100% no seu Mac: sem login, sem nuvem, sem telemetria, sem internet.
- Gratuito: não precisa de conta paga da Apple, nem da App Store, nem do Xcode completo.
- Não grava vídeo e não acessa câmera, microfone ou a tela.

---

## 1. Requisitos

- macOS 14 (Sonoma) ou mais recente.
- **Command Line Tools da Apple** (gratuitas). Se ainda não tiver, rode no Terminal:

```bash
xcode-select --install
```

O Xcode completo é opcional (só se você quiser abrir o projeto nele).

---

## 2. Compilar e instalar

No Terminal, entre na pasta `codigo-fonte` (baixada do GitHub) e rode o script de build. Por exemplo, se ela
estiver em Downloads:

```bash
cd ~/Downloads/Teleprompter-Mac-main/codigo-fonte
```

```bash
zsh scripts/build-app.sh --install --universal
```

`--universal` gera um app que roda tanto em Mac com chip Apple quanto em Mac com Intel.

O script:

1. compila em modo *release* (numa pasta de cache, fora do iCloud);
2. monta o pacote `Teleprompter Ethos.app` com ícone;
3. assina localmente (assinatura *ad hoc*, gratuita);
4. coloca uma cópia em `dist/` e, com `--install`, também em `~/Applications` (a pasta Aplicativos do seu usuário).

Sem `--install`, o app fica só em `dist/Teleprompter Ethos.app`. Arraste-o para a pasta Aplicativos, se preferir.

### Sobre assinatura e o primeiro uso

- O app é assinado “ad hoc” (sem certificado da Apple). Isso basta para uso local.
- Como foi compilado **no próprio Mac**, ele abre normalmente com duplo clique.
- Se você copiar o `.app` para outro Mac (por AirDrop, pendrive, download), o macOS pode bloquear a primeira abertura.
  Nesse caso: clique com o botão direito no app ▸ **Abrir** ▸ **Abrir**. Ou vá em **Ajustes do Sistema ▸ Privacidade
  e Segurança** e clique em **Abrir Mesmo Assim**. O mais simples é recompilar no outro Mac com o script.
- **Nenhuma permissão especial é pedida.** Os atalhos globais usam uma API pública que não exige Acessibilidade nem
  Monitoramento de Entrada (veja a seção 6).

### Abrir no Xcode (opcional)

1. Abra o Xcode ▸ **File ▸ Open…** ▸ escolha a pasta `Teleprompter-Ethos` (ou o arquivo `Package.swift`).
2. Selecione o esquema **TeleprompterEthos** e o destino **My Mac**.
3. **Product ▸ Run** (⌘R) para executar; **Product ▸ Test** (⌘U) para os testes.

Rodando pelo Xcode, o app funciona igual, mas o ícone do Dock pode aparecer durante a execução. Para o uso diário,
prefira o `.app` gerado pelo script.

---

## 3. Uso rápido (passo a passo)

1. **Abra o app.** Aparecem o editor de roteiros e, no alto da tela, a sobreposição com moldura amarela tracejada
   (modo **Ajustar**). Na barra de menus surge um ícone de pergaminho 📜.
2. **Carregue o roteiro:** cole o texto num roteiro novo (**Novo**) ou use **Importar** para abrir um `.txt`.
   Clique no roteiro na lista para escolhê-lo para leitura.
3. **Abra o OBS** e deixe-o como estiver (pode até deixá-lo em foco).
4. **Posicione a sobreposição perto da câmera:** arraste-a pelo meio e redimensione arrastando as **marcas amarelas**
   (nos quatro cantos e no meio de cada borda). Também dá para definir largura e altura em **Ajustes ▸ Fundo e foco**,
   ou usar **📜 ▸ Restaurar tamanho e posição da sobreposição**. Ajuste letra e velocidade na barra da própria
   sobreposição.
5. Clique em **Ler**: a moldura e os controles somem e os cliques passam a atravessar a sobreposição até o OBS.
6. **Inicie a leitura** com **F8**, mesmo com o OBS em foco. Pause e retome com o mesmo atalho.
7. Para mexer de novo na sobreposição, volte ao modo Ajustar com **⌃⌥L** ou pelo ícone 📜 na barra de menus.

---

## 4. Modos da sobreposição

| Modo | O que acontece |
|---|---|
| **Ajustar** | Moldura amarela, barra de controles, arrastar para mover, marcas amarelas nos cantos e bordas para redimensionar. Rolar o trackpad ou a roda do mouse sobre o texto reposiciona a leitura (e pausa). Sempre aparece um véu leve; sem ele, áreas 100% transparentes deixariam o clique passar e a janela não poderia ser arrastada. |
| **Ler** | Sem moldura e sem controles. **Todos os cliques e rolagens atravessam** a sobreposição e chegam ao app de trás. |

**Sempre há uma saída do modo Ler:**

- pelo atalho global **⌃⌥L**;
- pelo ícone 📜 na barra de menus (o primeiro item fica em negrito: “Voltar ao modo Ajustar”);
- pelo editor (seletor Ajustar/Ler).

O app sempre **abre em Ajustar**, nunca em Ler. Assim, a sobreposição nunca fica inacessível.

Para **esconder a sobreposição** sem fechar o app, use **⌃⌥H**, o menu 📜 ou o botão 👁 da barra. Esconder também
pausa a leitura.

---

## 5. Atalhos globais (padrão)

Funcionam com o OBS ou qualquer outro app em foco.

| Ação | Atalho |
|---|---|
| Iniciar / pausar / retomar | **F8** |
| Aumentar velocidade (+5 pt/s) | **⌃⌥=** |
| Diminuir velocidade (−5 pt/s) | **⌃⌥-** |
| Mostrar / esconder sobreposição | **⌃⌥H** |
| Alternar Ajustar / Ler | **⌃⌥L** |
| Voltar ao começo | **F7** |

(⌃ = Control, ⌥ = Option)

Para mudar um atalho: **Ajustes ▸ Atalhos**. Clique na combinação e pressione as novas teclas (Esc cancela).

- F7 e F8 são aceitas sem modificadores; as demais teclas exigem ⌘, ⌃ ou ⌥. Teclas simples como Espaço, setas ou R **nunca** são capturadas globalmente.
- **Conflitos detectados e informados:**
  - combinação repetida entre ações deste app;
  - combinação já registrada por outro app (o macOS recusa o registro);
  - atalho ativo do macOS (em Ajustes do Sistema ▸ Teclado ▸ Atalhos).
- **Não detectáveis:** atalhos internos de outros apps, como as teclas de atalho configuradas dentro do próprio OBS.
  Se você configurou F8 no OBS, por exemplo, escolha outra combinação aqui.

---

## 6. Privacidade e permissões

- Os atalhos usam `RegisterEventHotKey` (API pública da Apple). O macOS avisa o app **somente** quando a combinação
  exata é pressionada. **Nada do que você digita em outros apps é lido, monitorado ou registrado.**
- Por isso, **nenhuma permissão é necessária**: nem Acessibilidade, nem Monitoramento de Entrada, nem Gravação de Tela,
  nem câmera ou microfone.
- Limitação do macOS: enquanto um campo de senha estiver ativo (a chamada “entrada segura”), os atalhos globais de
  todos os apps ficam suspensos. Eles voltam a funcionar quando o campo de senha sai de foco.

---

## 7. Aparência e rolagem

Na barra da sobreposição (modo Ajustar) ou em **Ajustes**:

- **Texto:** tamanho, peso, cor, opacidade, espaçamento entre linhas, largura de leitura, alinhamento, contorno
  discreto, sombra e espelhamento horizontal. O espelhamento vale só para o texto; os controles continuam legíveis.
- **Fundo e foco:** opacidade do fundo de 0% (transparente) a 100%, independente da opacidade do texto. Também:
  cor do fundo, margem superior, posição e exibição da área de foco (faixa clara com marcadores amarelos).
- **Rolagem:**
  - velocidade contínua de 5 a 400 **pt/s** (pontos por segundo, ou seja, quanto o texto sobe por segundo);
  - contagem regressiva desligada, 3, 5 ou 10 s.

Como a rolagem se comporta:

- **Base no tempo:** a rolagem segue o tempo decorrido e não a taxa de atualização da tela. Fica igual a 60 Hz ou 120 Hz.
- **Começo e fim:** o roteiro começa com a primeira linha na área de foco e termina quando a última linha passa por ela.
  Ao chegar ao fim, a leitura para sozinha.
- **Ajustes durante a pausa:** ao mudar fonte, largura ou espaçamento, o trecho que estava na área de foco continua lá.
- **Suspensão do Mac:** ao suspender, a leitura pausa. Ao reativar, ela continua pausada e no mesmo ponto, sem salto.

---

## 8. Usando com o OBS: “visível para mim” × “visível na gravação”

A sobreposição **sempre aparece na sua tela**. Se ela **também entra no vídeo**, depende do tipo de captura do OBS:

| Fonte no OBS | A sobreposição aparece na gravação? |
|---|---|
| **Captura de janela** / “Captura de tela do macOS” no modo **Janela** (só o app que você quer mostrar) | Normalmente **não**: só o conteúdo daquela janela é capturado. |
| “Captura de tela do macOS” no modo **Aplicativo** (só outro app) | Normalmente **não**. |
| **Captura de tela inteira** / monitor (“Tela” / “Display”) | Normalmente **sim**: entra como qualquer janela visível. |
| **Câmera** (Dispositivo de captura de vídeo) | **Nunca**: a câmera não vê a tela. |

Isso varia com a versão do OBS, a versão do macOS e o método de captura. **Não há garantia.** Por isso:

### Teste antes de gravar para valer (1 minuto)

1. Deixe a sobreposição visível e rolando, no lugar onde vai usá-la.
2. No OBS, clique em **Iniciar gravação** e grave uns 10 segundos.
3. Pare e abra o arquivo gravado.
4. Se o texto do teleprompter aparecer no vídeo:
   - troque a fonte de “tela inteira” por captura de **janela** ou de **aplicativo**; ou
   - mova a sobreposição para um monitor que não está sendo capturado.
5. Repita o teste sempre que mudar a cena, a fonte ou atualizar o macOS ou o OBS.

### Opção experimental: ocultar das capturas

Em **Ajustes ▸ Gravação** existe a opção “Pedir ao macOS para ocultar a sobreposição de capturas de tela”. Ela usa
a propriedade pública da janela `sharingType = .none`.

Em versões recentes do macOS, capturas feitas com ScreenCaptureKit (o método do OBS moderno) **podem ignorar** esse
pedido. Trate a opção como tentativa e confirme sempre com a gravação de teste.

---

## 9. Spaces, tela cheia e vários monitores: o que esperar

- **Acima de outros apps:** a sobreposição usa o nível “barra de status”. Fica acima de janelas comuns e de janelas
  “sempre no topo” (inclusive as do OBS), mesmo quando o OBS está em foco.
- **Foco:** é um painel que **não ativa** o app. Mostrar a sobreposição ou iniciar a leitura não tira o foco do OBS.
- **Spaces:** está configurada para aparecer em todos os Spaces (`canJoinAllSpaces`) e sobre apps em tela cheia
  (`fullScreenAuxiliary`).
- **Onde ela não fica por cima:** menus abertos, alertas do sistema, Central de Notificações, Mission Control,
  tela de bloqueio, janela de login, proteção de tela e diálogos de senha do sistema. Não se promete funcionamento
  acima de telas protegidas do sistema nem de toda janela possível.
- **Vários monitores:** a posição é salva e restaurada. Se o monitor onde ela estava for desconectado, ou se a janela
  ficar fora de qualquer tela, ela volta automaticamente para uma área visível da tela principal.

---

## 10. Editor e dados

- Para criar, renomear (botão “Renomear” ou clique direito) ou excluir, use os botões do editor. A exclusão pede
  confirmação.
- **Salvamento automático:** cada alteração é salva meio segundo depois, e também ao fechar o editor e ao encerrar o app.
- **Onde ficam os dados:** `~/Library/Application Support/Teleprompter Ethos/`
  - `roteiros.json` — todos os roteiros;
  - `preferencias.json` — aparência, velocidade, atalhos e posição da janela.
- **Falhas de gravação:** se o disco estiver cheio ou a pasta protegida, aparece um aviso laranja no editor e um ⚠︎
  no ícone da barra de menus, com a opção de tentar de novo. Nada se perde enquanto o app estiver aberto.
- **Arquivo danificado:** se um arquivo estiver corrompido, o app guarda uma cópia (`…danificado-<data>.json`),
  avisa e continua funcionando.
- **Importar/Exportar .txt:**
  - a exportação grava sempre em **UTF-8**, preservando acentos e quebras de linha;
  - a importação aceita UTF-8 (com ou sem BOM) e UTF-16;
  - arquivos antigos em Latin-1/Windows-1252 também são aceitos, com um aviso para você conferir os acentos.
- **Primeiro uso:** um roteiro curto de exemplo é criado.

---

## 11. Testes

### Testes do núcleo

Cobrem rolagem, persistência, `.txt`, telas e atalhos (28 testes):

```bash
zsh scripts/test.sh
```

### Teste do app real

Usa uma pasta de dados separada; seus roteiros não são tocados:

```bash
"dist/Teleprompter Ethos.app/Contents/MacOS/TeleprompterEthos" --data-dir /tmp/tp-teste --autotest /tmp/tp-resultado.json
```

O teste do app real:

- coloca outro app em primeiro plano (Finder, ou o OBS com `--front-app com.obsproject.obs-studio`);
- verifica 34 itens:
  - visibilidade e ordem das janelas;
  - que mostrar e ler não roubam o foco;
  - rolagem com outro app em foco;
  - pausar, retomar e mudar a velocidade;
  - contagem regressiva;
  - suspensão e reativação;
  - preservação do trecho em leitura;
  - fim do roteiro;
  - modos Ler e Ajustar;
  - recuperação de janela fora da tela;
  - redimensionamento pelos cantos, pelas bordas e pelos Ajustes, respeitando o tamanho mínimo;
  - registro dos atalhos e gravação em disco.

### O que foi verificado e o que depende de você

**Verificado automaticamente** neste Mac (macOS 26.6, um monitor):

- tudo o que está nos testes acima;
- inclusive com o **OBS aberto e em primeiro plano**: a sobreposição ficou listada acima das janelas do OBS, rolou
  normalmente e não tirou o foco dele.

**Depende de validação manual** (exigiria permissões de Acessibilidade ou de Gravação de Tela, que não foram concedidas,
ou de hardware ausente):

- **Teclas reais:** pressionar os atalhos fisicamente com o OBS em foco. O registro foi verificado; o caminho da ação
  (o mesmo do menu) também.
- **Cliques reais:** clicar no OBS através da sobreposição no modo Ler. A propriedade que deixa os cliques passarem foi
  verificada. Durante os testes no modo Ler, o app recebeu zero eventos de rolagem, mesmo com o mouse em uso. No modo
  Ajustar, o mesmo uso gerou centenas.
- **Gravação:** se a sobreposição aparece ou não no vídeo (seção 8).
- **Tela cheia e Spaces:** OBS em tela cheia e troca de Spaces. A configuração foi verificada, a troca real não.
- **Dois monitores e desconexão real:** a lógica de recuperação foi testada com telas simuladas e com a janela
  colocada fora da tela.
- **Suspensão real:** o teste usou as notificações de suspender e reativar do sistema.

---

## 12. Organização do código

```
Package.swift                      Projeto (abre no Xcode)
Sources/TeleprompterCore/          Lógica sem interface (testável)
  ScrollEngine.swift               Controle da rolagem (tempo decorrido, pausa, fim, contagem)
  Store.swift                      Persistência local em JSON, salvamento automático, erros
  Models.swift                     Roteiro, preferências, opções
  KeyCombo.swift                   Combinações de teclas, padrões, duplicatas
  TextFileIO.swift                 Importar/exportar .txt (UTF-8)
  ScreenGeometry.swift             Manter a janela numa tela visível
Sources/TeleprompterEthos/         Aplicativo
  OverlayWindowController.swift    Janela flutuante (nível, Spaces, modos, posição, monitores)
  OverlayRootView.swift            Fundo, moldura, alças de redimensionamento
  TeleprompterTextView.swift       Desenho e rolagem do texto (display link, âncora de leitura)
  OverlayControls.swift            Barra de controles (SwiftUI)
  HotkeyManager.swift              Atalhos globais (Carbon RegisterEventHotKey)
  StatusMenuController.swift       Ícone e menu na barra de menus
  WindowCoordinator.swift          Editor/Ajustes, Dock e menu principal
  EditorView.swift, SettingsView.swift
  AppModel.swift                   Coordena tudo
  AutoTest.swift                   Teste automático do app real (--autotest)
Tests/TeleprompterCoreTests/       Testes do núcleo
scripts/                           build-app.sh, test.sh, make-icon.swift
```

Sem dependências externas. Nenhum recurso é baixado durante o uso.

### Teclas F7 e F8 no Mac

F8 inicia, pausa e retoma a leitura; F7 volta ao início e deixa a leitura parada. Os padrões antigos desses dois comandos são migrados automaticamente ao abrir esta versão.

Se essas teclas acionarem controles de mídia, use Fn/🌐 + F7 ou F8, ou habilite “Usar as teclas F1, F2 etc. como teclas de função padrão” nos ajustes de teclado do macOS. O aplicativo não altera essa preferência do sistema.
