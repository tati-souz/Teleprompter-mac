import AppKit
import Combine
import QuartzCore
import TeleprompterCore

/// Desenha o roteiro e o faz rolar.
///
/// - O texto é diagramado uma vez (NSLayoutManager) e, a cada quadro, só as linhas visíveis são desenhadas.
/// - O avanço vem do `ScrollEngine`, com base no tempo decorrido informado pelo display link
///   (independe de 60/120 Hz).
/// - Mudanças de fonte, largura ou espaçamento preservam o trecho que está na área de foco.
@MainActor
final class TeleprompterTextView: NSView {
    private let storage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let container = NSTextContainer(size: .zero)
    private let engine: ScrollEngine
    private var prefs = Preferences()
    private var text = ""
    private var link: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    private var cachedLineHeight: CGFloat = 50

    var isAdjustMode = true { didSet { needsDisplay = true } }
    var isEmptyLayout: Bool { storage.length == 0 }

    init(engine: ScrollEngine) {
        self.engine = engine
        super.init(frame: .zero)
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        layoutManager.allowsNonContiguousLayout = false
        container.lineFragmentPadding = 0
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay

        engine.$state
            .sink { [weak self] state in
                DispatchQueue.main.async {
                    self?.link?.isPaused = !state.isRunning
                    self?.needsDisplay = true
                }
            }.store(in: &cancellables)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Display link

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, link == nil else { return }
        let l = displayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        l.isPaused = !engine.state.isRunning
        link = l
    }

    @objc private func step(_ l: CADisplayLink) {
        if engine.tick(now: l.timestamp) { needsDisplay = true }
        if !engine.state.isRunning { l.isPaused = true }
    }

    // MARK: Geometria

    private var horizontalPadding: CGFloat { 16 }
    private var textAreaTop: CGFloat { min(CGFloat(prefs.topMargin), max(0, bounds.height - 40)) }
    private var focusY: CGFloat { textAreaTop + (bounds.height - textAreaTop) * CGFloat(prefs.focusPosition) }
    private var lineHeight: CGFloat { cachedLineHeight }
    /// Posição (na view) do topo do texto quando `offset == 0`: a primeira linha começa centrada na área de foco.
    private var startY: CGFloat { focusY - lineHeight / 2 }

    // MARK: Conteúdo

    func setText(_ newText: String, resetPosition: Bool) {
        guard newText != text || resetPosition || storage.length == 0 && !newText.isEmpty else { return }
        let anchor = resetPosition ? nil : captureAnchor()
        text = newText
        rebuildAttributes()
        relayout(restoring: anchor)
        if resetPosition { engine.rewind() }
        needsDisplay = true
    }

    func apply(_ p: Preferences) {
        let layoutKeys: (Preferences) -> [AnyHashable] = {
            [$0.fontSize, $0.fontWeight, $0.lineSpacing, $0.readingWidth, $0.alignment, $0.topMargin, $0.focusPosition]
        }
        let styleKeys: (Preferences) -> [AnyHashable] = {
            [$0.textColor, $0.textOpacity, $0.outline, $0.shadow, $0.mirror, $0.showFocusArea]
        }
        let first = storage.length == 0 && text.isEmpty
        let layoutChanged = layoutKeys(p) != layoutKeys(prefs)
        let styleChanged = styleKeys(p) != styleKeys(prefs)
        guard first || layoutChanged || styleChanged else { return }

        let anchor = layoutChanged ? captureAnchor() : nil
        prefs = p
        rebuildAttributes()
        if layoutChanged || first { relayout(restoring: anchor) }
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        let anchor = changed ? captureAnchor() : nil
        super.setFrameSize(newSize)
        if changed { relayout(restoring: anchor) }
    }

    private func font() -> NSFont {
        let weight: NSFont.Weight
        switch prefs.fontWeight {
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        case .heavy: weight = .heavy
        }
        return NSFont.systemFont(ofSize: CGFloat(prefs.fontSize), weight: weight)
    }

    private func rebuildAttributes() {
        let f = font()
        let c = prefs.textColor
        let textAlpha = prefs.textOpacity
        let para = NSMutableParagraphStyle()
        para.lineHeightMultiple = CGFloat(prefs.lineSpacing)
        para.alignment = prefs.alignment == .center ? .center : .left
        para.paragraphSpacing = CGFloat(prefs.fontSize) * 0.1   // roteiros já usam linha em branco entre parágrafos
        para.lineBreakMode = .byWordWrapping

        var attrs: [NSAttributedString.Key: Any] = [
            .font: f,
            .paragraphStyle: para,
            .foregroundColor: NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: textAlpha),
        ]
        // Contorno e sombra em cor oposta à do texto, para legibilidade sobre áreas claras ou escuras.
        // O "contorno" é um halo rente às letras (sombra sem deslocamento, desenhada em duas passadas):
        // traço de contorno real (strokeWidth) revelaria as sobreposições internas dos glifos da fonte do sistema.
        let luminance = 0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue
        let edge: NSColor = luminance > 0.5 ? .black : .white
        let fs = CGFloat(prefs.fontSize)
        if prefs.outline || prefs.shadow {
            let s = NSShadow()
            switch (prefs.outline, prefs.shadow) {
            case (true, true):
                s.shadowBlurRadius = max(2, fs * 0.06)
                s.shadowOffset = NSSize(width: 0, height: -max(1, fs * 0.02))
                s.shadowColor = edge.withAlphaComponent(textAlpha)
            case (true, false):
                s.shadowBlurRadius = max(1.5, fs * 0.04)
                s.shadowOffset = .zero
                s.shadowColor = edge.withAlphaComponent(textAlpha)
            default:
                s.shadowBlurRadius = max(3, fs * 0.1)
                s.shadowOffset = NSSize(width: 0, height: -max(1, fs * 0.04))
                s.shadowColor = edge.withAlphaComponent(0.85 * textAlpha)
            }
            attrs[.shadow] = s
        }
        storage.setAttributedString(NSAttributedString(string: text, attributes: attrs))
        cachedLineHeight = layoutManager.defaultLineHeight(for: f) * CGFloat(prefs.lineSpacing)
    }

    private func relayout(restoring anchor: Anchor?) {
        let width = max(80, bounds.width * CGFloat(prefs.readingWidth) - 2 * horizontalPadding)
        container.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let used = storage.length == 0 ? 0 : layoutManager.usedRect(for: container).height
        // Termina quando a última linha já passou acima da área de foco.
        engine.maxOffset = Double(used + lineHeight * 0.1)
        if let anchor { restore(anchor) }
        needsDisplay = true
    }

    // MARK: Âncora de leitura

    enum Anchor {
        case start
        case end
        case character(index: Int, fraction: CGFloat)
    }

    /// Qual trecho está na área de foco agora.
    func captureAnchor() -> Anchor? {
        guard storage.length > 0, bounds.width > 0 else { return nil }
        if engine.offset <= 0.5 { return .start }
        if engine.offset >= engine.maxOffset - 0.5 { return .end }
        let docY = CGFloat(engine.offset) + lineHeight / 2
        let glyph = layoutManager.glyphIndex(for: CGPoint(x: 1, y: docY), in: container)
        let rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let fraction = rect.height > 0 ? min(max((docY - rect.minY) / rect.height, 0), 1) : 0
        return .character(index: layoutManager.characterIndexForGlyph(at: glyph), fraction: fraction)
    }

    private func restore(_ anchor: Anchor) {
        switch anchor {
        case .start:
            engine.setOffset(0, pausing: false)
        case .end:
            engine.setOffset(engine.maxOffset, pausing: false)
        case .character(let index, let fraction):
            guard storage.length > 0 else { return }
            let glyph = layoutManager.glyphIndexForCharacter(at: min(index, storage.length - 1))
            let rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let docY = rect.minY + fraction * rect.height
            engine.setOffset(Double(docY - lineHeight / 2), pausing: false)
        }
    }

    /// Índice do caractere atualmente na área de foco (usado nos testes automáticos).
    var focusedCharacterIndex: Int? {
        if case .character(let i, _) = captureAnchor() { return i }
        return nil
    }

    // MARK: Desenho

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let top = textAreaTop
        let area = CGRect(x: 0, y: top, width: bounds.width, height: bounds.height - top)

        ctx.saveGState()
        ctx.clip(to: area)

        if prefs.showFocusArea { drawFocusArea() }

        if storage.length > 0 {
            ctx.saveGState()
            if prefs.mirror {   // espelha só o texto; controles e marcadores continuam legíveis
                ctx.translateBy(x: bounds.width, y: 0)
                ctx.scaleBy(x: -1, y: 1)
            }
            let origin = CGPoint(x: ((bounds.width - container.size.width) / 2).rounded(),
                                 y: startY - CGFloat(engine.offset))
            let visibleDoc = CGRect(x: 0, y: top - origin.y - lineHeight,
                                    width: container.size.width, height: area.height + 2 * lineHeight)
            let glyphs = layoutManager.glyphRange(forBoundingRect: visibleDoc, in: container)
            if glyphs.length > 0 {
                layoutManager.drawGlyphs(forGlyphRange: glyphs, at: origin)
                // Segunda passada reforça o halo do contorno.
                if prefs.outline { layoutManager.drawGlyphs(forGlyphRange: glyphs, at: origin) }
            }
            ctx.restoreGState()
        } else {
            drawCenteredLabel("Roteiro vazio — escreva ou importe um texto no editor.", size: 16, alpha: 0.85)
        }
        ctx.restoreGState()

        switch engine.state {
        case .countingDown(let remaining):
            drawCenteredLabel("\(Int(remaining.rounded(.up)))", size: min(140, bounds.height * 0.45), alpha: 0.95)
        case .finished where isAdjustMode:
            drawBottomHint("Fim do roteiro — ⏮ volta ao começo")
        default:
            if isAdjustMode {
                drawBottomHint("Arraste para mover · bordas para redimensionar · role para reposicionar o texto")
            }
        }
    }

    private func drawFocusArea() {
        let band = CGRect(x: 0, y: focusY - lineHeight * 0.6, width: bounds.width, height: lineHeight * 1.2)
        NSColor(white: 1, alpha: 0.07).setFill()
        band.fill(using: .sourceOver)
        // Marcadores laterais
        NSColor.systemYellow.withAlphaComponent(0.85).setFill()
        let s: CGFloat = min(12, lineHeight * 0.3)
        for x in [CGFloat(2), bounds.width - 2] {
            let dir: CGFloat = x < bounds.midX ? 1 : -1
            let p = NSBezierPath()
            p.move(to: CGPoint(x: x, y: focusY - s))
            p.line(to: CGPoint(x: x + dir * s, y: focusY))
            p.line(to: CGPoint(x: x, y: focusY + s))
            p.close()
            p.fill()
        }
    }

    private func drawCenteredLabel(_ string: String, size: CGFloat, alpha: CGFloat) {
        let shadow = NSShadow()
        shadow.shadowColor = .black
        shadow.shadowBlurRadius = 6
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
            .shadow: shadow,
        ]
        let s = NSAttributedString(string: string, attributes: attrs)
        let r = s.boundingRect(with: CGSize(width: bounds.width - 40, height: .greatestFiniteMagnitude),
                               options: [.usesLineFragmentOrigin])
        s.draw(with: CGRect(x: (bounds.width - r.width) / 2, y: (bounds.height - r.height) / 2,
                            width: r.width + 1, height: r.height + 1),
               options: [.usesLineFragmentOrigin])
    }

    private func drawBottomHint(_ string: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85),
        ]
        let s = NSAttributedString(string: string, attributes: attrs)
        let size = s.size()
        let rect = CGRect(x: (bounds.width - size.width) / 2 - 8, y: bounds.height - size.height - 14,
                          width: size.width + 16, height: size.height + 6)
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
        s.draw(at: CGPoint(x: rect.minX + 8, y: rect.minY + 3))
    }

    // MARK: Reposicionamento manual (modo Ajustar)

    override func scrollWheel(with event: NSEvent) {
        guard isAdjustMode else { return }
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * lineHeight
        engine.setOffset(engine.offset - Double(delta))   // pausa a leitura
        needsDisplay = true
    }
}
