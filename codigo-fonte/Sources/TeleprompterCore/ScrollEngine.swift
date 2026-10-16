import Foundation
import Combine

/// Controle da rolagem, independente de janela e de taxa de atualização da tela.
///
/// A posição avança `speed × tempo decorrido`. O relógio é fornecido de fora (`tick(now:)`),
/// o que torna o comportamento determinístico e testável. Intervalos grandes entre dois
/// quadros (suspensão do Mac, travamentos) são limitados a `maxFrameInterval`, evitando saltos.
public final class ScrollEngine: ObservableObject {
    public enum State: Equatable {
        case idle
        case countingDown(remaining: Double)
        case playing
        case paused
        case finished

        public var isRunning: Bool {
            switch self {
            case .playing, .countingDown: return true
            default: return false
            }
        }
    }

    @Published public private(set) var state: State = .idle
    /// Velocidade em pontos por segundo (pt/s).
    @Published public var speed: Double {
        didSet {
            let clamped = Self.clampSpeed(speed)
            if clamped != speed { speed = clamped }
        }
    }

    /// Posição atual (pontos). Não é `@Published` para não gerar atualizações de interface a cada quadro.
    public private(set) var offset: Double = 0
    /// Posição em que o roteiro termina (calculada pela camada de desenho).
    public var maxOffset: Double = 0 {
        didSet { if offset > maxOffset, state != .playing { offset = max(0, maxOffset) } }
    }
    public var countdownSeconds: Double = 3

    public static let maxFrameInterval: Double = 0.1

    private var lastTimestamp: Double?

    public init(speed: Double = 40, countdownSeconds: Double = 3) {
        self.speed = Self.clampSpeed(speed)
        self.countdownSeconds = countdownSeconds
    }

    public static func clampSpeed(_ v: Double) -> Double {
        min(max(v, 5), 400)
    }

    // MARK: Comandos

    public func togglePlayPause() {
        if state.isRunning { pause() } else { start() }
    }

    /// Inicia ou retoma. Ao fim do roteiro, recomeça do início.
    public func start() {
        if state == .finished || offset >= maxOffset { offset = 0 }
        lastTimestamp = nil
        state = countdownSeconds > 0 ? .countingDown(remaining: countdownSeconds) : .playing
    }

    public func pause() {
        lastTimestamp = nil
        switch state {
        case .playing: state = .paused
        case .countingDown: state = offset > 0 ? .paused : .idle
        default: break
        }
    }

    public func rewind() {
        offset = 0
        lastTimestamp = nil
        state = .idle   // volta ao começo sempre parado: o próximo "iniciar" refaz a contagem
    }

    /// Reposicionamento manual (sempre pausa a leitura).
    public func setOffset(_ value: Double, pausing: Bool = true) {
        if pausing, state.isRunning { pause() }
        offset = min(max(0, value), max(0, maxOffset))
        if state == .finished, offset < maxOffset { state = .paused }
    }

    /// Esquece o último instante: o próximo quadro não avança (usado após suspensão).
    public func resetClock() { lastTimestamp = nil }

    // MARK: Relógio

    /// Avança a rolagem. Retorna `true` quando a posição ou o estado mudou.
    @discardableResult
    public func tick(now: Double) -> Bool {
        guard state.isRunning else { lastTimestamp = nil; return false }
        guard let last = lastTimestamp else { lastTimestamp = now; return false }
        lastTimestamp = now
        let dt = min(max(0, now - last), Self.maxFrameInterval)
        if dt == 0 { return false }

        switch state {
        case .countingDown(let remaining):
            let r = remaining - dt
            state = r > 0 ? .countingDown(remaining: r) : .playing
            return true
        case .playing:
            offset += speed * dt
            if offset >= maxOffset {
                offset = max(0, maxOffset)
                state = .finished
                lastTimestamp = nil
            }
            return true
        default:
            return false
        }
    }
}

