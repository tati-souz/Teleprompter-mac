import AppKit
import SwiftUI
import TeleprompterCore

/// Conteúdo da sobreposição: fundo opcional, texto rolante e, no modo Ajustar,
/// barra de controles, moldura e alças de redimensionamento.
@MainActor
final class OverlayRootView: NSView {
    let textView: TeleprompterTextView
    private let background = OverlayBackgroundView()
    private let controls: FirstMouseHostingView<OverlayControls>
    private var handles: [ResizeHandle] = []
    private var adjusting = true

    init(model: AppModel) {
        textView = TeleprompterTextView(engine: model.engine)
        controls = FirstMouseHostingView(rootView: OverlayControls(model: model, engine: model.engine, store: model.store))
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(background)
        addSubview(textView)
        addSubview(controls)
        for edges: ResizeHandle.Edges in [.left, .right, .top, .bottom,
                                         [.top, .left], [.top, .right], [.bottom, .left], [.bottom, .right]] {
            let h = ResizeHandle(edges: edges)
            handles.append(h)
            addSubview(h)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Sem Auto Layout, o AppKit não refaz o layout sozinho quando a janela muda de tamanho.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    func apply(_ p: Preferences) {
        background.update(color: p.backgroundColor, opacity: p.backgroundOpacity)
        textView.apply(p)
    }

    func setAdjusting(_ on: Bool) {
        adjusting = on
        background.adjusting = on
        textView.isAdjustMode = on
        controls.isHidden = !on
        handles.forEach { $0.isHidden = !on }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        background.frame = bounds
        textView.frame = bounds
        let barHeight: CGFloat = 40
        controls.frame = CGRect(x: 8, y: 6, width: bounds.width - 16, height: barHeight)

        let t: CGFloat = 12  // espessura das bordas sensíveis
        let c: CGFloat = 28  // cantos
        let w = bounds.width, h = bounds.height
        for handle in handles {
            let e = handle.edges
            switch e {
            case [.top, .left]: handle.frame = CGRect(x: 0, y: 0, width: c, height: c)
            case [.top, .right]: handle.frame = CGRect(x: w - c, y: 0, width: c, height: c)
            case [.bottom, .left]: handle.frame = CGRect(x: 0, y: h - c, width: c, height: c)
            case [.bottom, .right]: handle.frame = CGRect(x: w - c, y: h - c, width: c, height: c)
            case .left: handle.frame = CGRect(x: 0, y: c, width: t, height: h - 2 * c)
            case .right: handle.frame = CGRect(x: w - t, y: c, width: t, height: h - 2 * c)
            case .top: handle.frame = CGRect(x: c, y: 0, width: w - 2 * c, height: t)
            default: handle.frame = CGRect(x: c, y: h - t, width: w - 2 * c, height: t)
            }
        }
    }
}

/// Fundo com opacidade própria (independente do texto). No modo Ajustar recebe
/// uma moldura tracejada e um preenchimento mínimo — sem ele, as áreas 100% transparentes
/// deixariam o clique passar e a janela não poderia ser arrastada.
final class OverlayBackgroundView: NSView {
    var adjusting = true { didSet { needsDisplay = true } }
    private var color = NSColor.black
    private var opacity: Double = 0

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    func update(color c: RGBAColor, opacity o: Double) {
        let ns = NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        guard ns != color || o != opacity else { return }
        color = ns
        opacity = o
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if adjusting {
            // Pixels com transparência total deixam o clique atravessar a janela (comportamento do macOS).
            // No modo Ajustar, todo o retângulo — inclusive cantos e bordas — recebe um mínimo de opacidade
            // para que as alças de redimensionamento recebam o clique.
            NSColor.black.withAlphaComponent(0.06).setFill()
            bounds.fill()
        }
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        let alpha = adjusting ? max(opacity, 0.18) : opacity
        if alpha > 0 {
            color.withAlphaComponent(alpha).setFill()
            path.fill()
        }
        if adjusting {
            NSColor.systemYellow.withAlphaComponent(0.9).setStroke()
            path.lineWidth = 2
            path.setLineDash([8, 5], count: 2, phase: 0)
            path.stroke()
        }
    }
}

/// Alça para redimensionar uma janela sem bordas.
final class ResizeHandle: NSView {
    struct Edges: OptionSet, Hashable {
        let rawValue: Int
        static let left = Edges(rawValue: 1), right = Edges(rawValue: 2), top = Edges(rawValue: 4), bottom = Edges(rawValue: 8)
    }

    let edges: Edges

    init(edges: Edges) {
        self.edges = edges
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    private var cursor: NSCursor {
        if #available(macOS 15.0, *) {
            let pos: NSCursor.FrameResizePosition
            switch edges {
            case [.top, .left]: pos = .topLeft
            case [.top, .right]: pos = .topRight
            case [.bottom, .left]: pos = .bottomLeft
            case [.bottom, .right]: pos = .bottomRight
            case .left: pos = .left
            case .right: pos = .right
            case .top: pos = .top
            default: pos = .bottom
            }
            return NSCursor.frameResize(position: pos, directions: .all)
        }
        if edges == .left || edges == .right { return .resizeLeftRight }
        if edges == .top || edges == .bottom { return .resizeUpDown }
        return .crosshair
    }

    /// Marcas amarelas visíveis em cada canto e no meio de cada borda, indicando onde pegar.
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemYellow.setStroke()
        let p = NSBezierPath()
        p.lineWidth = 4
        p.lineCapStyle = .round
        let b = bounds.insetBy(dx: 3, dy: 3)
        let arm: CGFloat = 16
        switch edges {
        case [.top, .left]:
            p.move(to: NSPoint(x: b.minX, y: b.minY + arm)); p.line(to: NSPoint(x: b.minX, y: b.minY)); p.line(to: NSPoint(x: b.minX + arm, y: b.minY))
        case [.top, .right]:
            p.move(to: NSPoint(x: b.maxX - arm, y: b.minY)); p.line(to: NSPoint(x: b.maxX, y: b.minY)); p.line(to: NSPoint(x: b.maxX, y: b.minY + arm))
        case [.bottom, .left]:
            p.move(to: NSPoint(x: b.minX, y: b.maxY - arm)); p.line(to: NSPoint(x: b.minX, y: b.maxY)); p.line(to: NSPoint(x: b.minX + arm, y: b.maxY))
        case [.bottom, .right]:
            p.move(to: NSPoint(x: b.maxX - arm, y: b.maxY)); p.line(to: NSPoint(x: b.maxX, y: b.maxY)); p.line(to: NSPoint(x: b.maxX, y: b.maxY - arm))
        case .left, .right:
            let x = edges == .left ? b.minX : b.maxX
            p.move(to: NSPoint(x: x, y: bounds.midY - 18)); p.line(to: NSPoint(x: x, y: bounds.midY + 18))
        default:
            let y = edges == .top ? b.minY : b.maxY
            p.move(to: NSPoint(x: bounds.midX - 18, y: y)); p.line(to: NSPoint(x: bounds.midX + 18, y: y))
        }
        p.stroke()
    }

    /// Laço de acompanhamento do arrasto (padrão do AppKit): lê os eventos em ordem até soltar o botão.
    /// Usa a posição global do evento, que não muda quando a própria janela é redimensionada.
    override func mouseDown(with event: NSEvent) {
        guard let window, let start = event.cgEvent?.location else { return }
        let startFrame = window.frame
        while let e = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if e.type == .leftMouseUp { break }
            guard let p = e.cgEvent?.location else { continue }
            // Coordenadas globais do Quartz têm y para baixo; as da janela, y para cima.
            window.setFrame(resized(startFrame, dx: p.x - start.x, dy: start.y - p.y, minSize: window.minSize), display: true)
        }
        (window.delegate as? OverlayWindowController)?.saveFrame()
    }

    private func resized(_ start: NSRect, dx: CGFloat, dy: CGFloat, minSize: NSSize) -> NSRect {
        var f = start
        if edges.contains(.right) { f.size.width = max(minSize.width, start.width + dx) }
        if edges.contains(.left) {
            let w = max(minSize.width, start.width - dx)
            f.origin.x = start.maxX - w
            f.size.width = w
        }
        if edges.contains(.top) { f.size.height = max(minSize.height, start.height + dy) }
        if edges.contains(.bottom) {
            let h = max(minSize.height, start.height - dy)
            f.origin.y = start.maxY - h
            f.size.height = h
        }
        return f
    }
}

/// NSHostingView que aceita o primeiro clique (a sobreposição nunca é a janela ativa).
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
}
