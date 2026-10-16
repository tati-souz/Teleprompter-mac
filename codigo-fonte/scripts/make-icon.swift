// Gera Support/AppIcon.icns (ícone simples: folha de roteiro sobre fundo escuro).
// Uso: swift scripts/make-icon.swift <pasta-de-saida-iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    // FULLBLEED=1: ícone quadrado e opaco (o iPhone arredonda os cantos sozinho).
    let fullBleed = ProcessInfo.processInfo.environment["FULLBLEED"] == "1"
    let inset = fullBleed ? 0 : s * 0.09
    let radius = fullBleed ? 0 : s * 0.2
    let bg = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset),
                          xRadius: radius, yRadius: radius)
    NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.16, blue: 0.22, alpha: 1),
               ending: NSColor(srgbRed: 0.04, green: 0.06, blue: 0.09, alpha: 1))!.draw(in: bg, angle: -90)
    // Linhas de texto
    let gold = NSColor(srgbRed: 0.84, green: 0.70, blue: 0.42, alpha: 1)
    let widths: [CGFloat] = [0.56, 0.48, 0.56, 0.36]
    for (i, w) in widths.enumerated() {
        let y = s * (0.62 - CGFloat(i) * 0.12)
        let r = NSRect(x: s * 0.22, y: y, width: s * w, height: s * 0.055)
        (i == 1 ? gold : NSColor(white: 0.95, alpha: 0.9)).setFill()
        NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2).fill()
    }
    // Seta de rolagem
    gold.setFill()
    let a = NSBezierPath()
    a.move(to: NSPoint(x: s * 0.80, y: s * 0.70))
    a.line(to: NSPoint(x: s * 0.72, y: s * 0.58))
    a.line(to: NSPoint(x: s * 0.88, y: s * 0.58))
    a.close()
    a.fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: out.appendingPathComponent("icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
