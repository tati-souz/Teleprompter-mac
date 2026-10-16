import Foundation
import CoreGraphics

/// Regras para manter a sobreposição sempre alcançável em alguma tela.
public enum ScreenGeometry {
    /// Área mínima da janela que precisa estar visível para mantermos a posição salva.
    public static let minimumVisible = CGSize(width: 120, height: 60)

    /// Devolve um quadro seguro: mantém o salvo se ele estiver suficientemente visível
    /// em alguma tela (limitando o tamanho a essa tela); caso contrário, usa `fallback`.
    public static func validatedFrame(saved: CGRect?, screens: [CGRect], fallback: CGRect) -> CGRect {
        guard let saved, saved.width > 0, saved.height > 0, !screens.isEmpty else { return fallback }

        let best = screens.max { a, b in
            area(a.intersection(saved)) < area(b.intersection(saved))
        }!
        let visible = best.intersection(saved)
        guard !visible.isNull,
              visible.width >= minimumVisible.width,
              visible.height >= minimumVisible.height else { return fallback }

        // A janela inteira cabe na tela? Se não, reduz e reposiciona para dentro.
        var frame = saved
        frame.size.width = min(frame.width, best.width)
        frame.size.height = min(frame.height, best.height)
        frame.origin.x = min(max(frame.minX, best.minX), best.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, best.minY), best.maxY - frame.height)
        return frame
    }

    /// Posição padrão: faixa no alto da tela, centralizada (perto da câmera do Mac).
    public static func defaultFrame(in screen: CGRect) -> CGRect {
        let width = min(900, screen.width * 0.7)
        let height = min(360, screen.height * 0.4)
        return CGRect(x: screen.midX - width / 2, y: screen.maxY - height - 8, width: width, height: height)
    }

    private static func area(_ r: CGRect) -> CGFloat {
        r.isNull ? 0 : r.width * r.height
    }
}
