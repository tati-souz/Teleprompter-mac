# 📜 Teleprompter para Mac

Um teleprompter que fica **flutuando por cima do OBS** (ou de qualquer outro app) enquanto você grava para o
YouTube ou o Instagram. O texto sobe sozinho numa camada transparente, e você continua vendo e usando o que está
atrás.

- ✅ **Grátis.** Sem login, sem assinatura, sem anúncio.
- ✅ **Privado.** Seus roteiros ficam só no seu Mac. O app não usa internet, não acessa câmera nem microfone e não
  lê o que você digita em outros programas.
- ✅ **Controle por teclado** mesmo com o OBS em foco: **F8** inicia e pausa a leitura.
- ✅ Funciona em Mac com **chip Apple (M1, M2, M3…)** e com **Intel**, a partir do **macOS 14 (Sonoma)**.

---

## ⬇️ Como baixar e instalar (2 minutos)

1. Baixe o app: **[Teleprompter-Ethos-Mac.zip](https://github.com/tati-souz/Teleprompter-Mac/raw/main/Teleprompter-Ethos-Mac.zip)**
2. Abra a pasta **Downloads** e dê dois cliques no `.zip`. Aparece o **Teleprompter Ethos**.
3. Arraste o **Teleprompter Ethos** para a pasta **Aplicativos**.
4. Dê dois cliques nele para abrir.

### “O macOS não pôde verificar…” — é normal na primeira vez

O app é gratuito e não foi pago o registro anual da Apple (US$ 99). Por isso, na primeira vez o macOS mostra um
aviso. Faça **uma vez só**:

**macOS 15 (Sequoia) ou mais recente:**
1. No aviso, clique em **OK** (ou **Concluído**).
2. Abra **Ajustes do Sistema ▸ Privacidade e Segurança**.
3. Role até o fim. Ao lado de *“Teleprompter Ethos foi bloqueado…”*, clique em **Abrir Mesmo Assim**.
4. Digite a senha do Mac e clique em **Abrir**.

**macOS 14 (Sonoma):** clique com o **botão direito** no app ▸ **Abrir** ▸ **Abrir**.

Depois disso, ele abre normalmente com dois cliques.

---

## 🎬 Como usar com o OBS

1. **Abra o app.** Aparecem duas coisas:
   - o **editor de roteiros**;
   - no alto da tela, a **sobreposição**, com moldura amarela tracejada.

   Na barra de menus, lá em cima, surge um ícone de pergaminho **📜**.
2. **Coloque o roteiro:** clique em **Novo** e cole o texto, ou use **Importar** para abrir um arquivo `.txt`.
3. **Abra o OBS** normalmente.
4. **Posicione a sobreposição perto da câmera:**
   - arraste-a pelo meio;
   - redimensione puxando as **marcas amarelas** dos cantos e das bordas;
   - ajuste o tamanho da letra e a velocidade na barra da própria sobreposição.
5. Clique em **Ler**. A moldura e os botões somem, e os **cliques passam através do texto** até o OBS.
6. Aperte **F8** para começar. O texto sobe sozinho, mesmo com o OBS em foco. **F8** de novo pausa e retoma.
7. Para mexer de novo na sobreposição, aperte **⌃⌥L** (Control + Option + L) ou use o ícone **📜 ▸ Voltar ao modo
   Ajustar**.

### Atalhos de teclado

| Ação | Atalho |
|---|---|
| Iniciar / pausar / retomar | **F8** |
| Voltar ao começo do roteiro | **F7** |
| Mais rápido / mais devagar | **⌃⌥=** / **⌃⌥-** |
| Mostrar / esconder a sobreposição | **⌃⌥H** |
| Alternar entre Ajustar e Ler | **⌃⌥L** |

(⌃ = Control, ⌥ = Option. Dá para trocar qualquer atalho em **Ajustes ▸ Atalhos**.)

> **F7 e F8 controlam música ou volume em vez do teleprompter?** Aperte junto a tecla **fn** (ou 🌐): **fn + F8**.
> Ou, em **Ajustes do Sistema ▸ Teclado ▸ Atalhos de Teclado ▸ Teclas de Função**, ative *“Usar as teclas F1, F2
> etc. como teclas de função padrão”*.

### Ajustes de aparência

Em **📜 ▸ Ajustes…** você escolhe:
- **Texto:** tamanho, peso e cor da letra; espaçamento entre linhas; largura do texto.
- **Fundo:** de totalmente transparente até escuro. Isso não apaga as letras.
- **Leitura:** linha de leitura; margem superior; contagem regressiva (desligada, 3, 5 ou 10 s).
- **Espelho:** espelhar o texto, para vidro de teleprompter.

---

## 🎥 Ele aparece no vídeo gravado?

A sobreposição sempre aparece **na sua tela**. Se ela também entra **no vídeo**, depende do tipo de captura no OBS:

| O que o OBS captura | O teleprompter aparece no vídeo? |
|---|---|
| **Câmera** | **Nunca.** |
| **Captura de janela** ou de **aplicativo** (só outro programa) | Normalmente **não**. |
| **Captura da tela inteira** (monitor) | Normalmente **sim**. |

👉 **Antes de gravar para valer, faça um teste de 10 segundos** e assista ao resultado. Se o texto aparecer:
- troque a captura de tela inteira por captura de janela; ou
- coloque o teleprompter num monitor que não está sendo gravado.

---

## ❓ Problemas comuns

**Não acho a sobreposição / ela sumiu**
Clique no **📜** na barra de menus ▸ **Mostrar sobreposição**. Se ela estiver fora da tela, use
**📜 ▸ Restaurar tamanho e posição da sobreposição**.

**Não consigo clicar na sobreposição**
Ela está no modo **Ler**, em que os cliques atravessam. Aperte **⌃⌥L** ou use **📜 ▸ Voltar ao modo Ajustar**.

**Um atalho não funciona**
Ele pode estar em uso por outro programa, inclusive pelo próprio OBS. Em **📜 ▸ Ajustes… ▸ Atalhos**, clique no
atalho e escolha outra combinação. O app avisa quando detecta conflito.

**Onde ficam meus roteiros?**
No seu Mac, em `~/Library/Application Support/Teleprompter Ethos/`. Para guardar uma cópia, use **Exportar .txt**
no editor.

**Como fecho o app?**
**📜 ▸ Encerrar Teleprompter Ethos.**

---

## 🔒 Privacidade e permissões

- O app **não pede nenhuma permissão especial**: nem Acessibilidade, nem Gravação de Tela, nem câmera ou microfone.
- Os atalhos usam um recurso padrão do macOS: o sistema só avisa o app quando **aquela combinação exata** é
  apertada. Nada do que você digita em outros programas é lido ou registrado.
- Não há conexão com a internet, conta, nuvem ou rastreamento.

---

## 🛠️ Para quem quer compilar

O código-fonte completo (Swift, SwiftUI e AppKit) está na pasta [`codigo-fonte`](codigo-fonte). Para compilar,
basta ter as Command Line Tools da Apple, que são gratuitas (`xcode-select --install`). As instruções detalhadas
estão no [README técnico](codigo-fonte/README.md).

📱 Também existe a versão para iPhone, que grava com a câmera frontal:
**[Teleprompter-iPhone](https://github.com/tati-souz/Teleprompter-iPhone)**.
