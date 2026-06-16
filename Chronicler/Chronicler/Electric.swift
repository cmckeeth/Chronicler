import SwiftUI

// Full-screen animated electricity: roving lightning bolts that strobe + flicker,
// plus drifting glow nodes. Sits behind content (additive screen blend) so the whole
// app looks like it's buzzing with current. Deterministic from time (no RNG) so it's
// resume-safe and cheap — one offscreen-rendered Canvas per frame.
struct ElectricBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in draw(ctx, size, t) }
                .blendMode(.screen)
                .drawingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height

        // Drifting soft glow nodes — the ambient "charge in the air".
        for k in 0..<max(1, Int(3 * intensity)) {
            let p = Double(k) * 2.3
            let gx = w * (0.5 + 0.42 * sin(t * 0.19 + p))
            let gy = h * (0.5 + 0.42 * cos(t * 0.15 + p * 1.1))
            let pulse = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 1.5 + p))
            let r = 110.0 * pulse
            ctx.fill(Path(ellipseIn: CGRect(x: gx - r, y: gy - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(
                        Gradient(colors: [Theme.verdigris.opacity(0.12 * pulse * intensity),
                                          Theme.verdigris.opacity(0)]),
                        center: CGPoint(x: gx, y: gy), startRadius: 0, endRadius: r))
        }

        // Strobing lightning bolts.
        let bolts = max(2, Int(6 * intensity))
        for k in 0..<bolts {
            let phase = Double(k) * 1.7
            let strobe = pow(max(0, sin(t * (2.2 + Double(k % 3) * 0.6) + phase)), 6)  // sharp bursts
            let flick = 0.55 + 0.45 * sin(t * 42 + phase)                              // fast flicker while lit
            let alpha = strobe * (0.35 + 0.65 * flick) * min(1.3, intensity)
            if alpha < 0.02 { continue }
            let a = CGPoint(x: w * (0.5 + 0.52 * sin(t * 0.13 + phase)),
                            y: h * (0.10 + 0.12 * sin(t * 0.21 + phase * 1.3)))
            let b = CGPoint(x: w * (0.5 + 0.52 * sin(t * 0.11 + phase + 2.0)),
                            y: h * (0.80 + 0.18 * sin(t * 0.17 + phase * 0.7)))
            bolt(ctx, a, b, t, k, alpha)
        }
    }

    private func bolt(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ t: Double, _ seed: Int, _ alpha: Double) {
        let segs = 16
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(1, hypot(dx, dy))
        let nx = -dy / len, ny = dx / len
        var pts: [CGPoint] = []
        for i in 0...segs {
            let f = Double(i) / Double(segs)
            let env = sin(f * .pi)
            let j = sin(t * 9 + Double(seed) * 3.1 + f * 13) * 46 * env
                  + sin(t * 23 + Double(seed) + f * 31) * 18 * env
            pts.append(CGPoint(x: a.x + dx * f + nx * j, y: a.y + dy * f + ny * j))
        }
        var path = Path()
        path.move(to: pts[0]); for p in pts.dropFirst() { path.addLine(to: p) }
        ctx.stroke(path, with: .color(Theme.verdigris.opacity(0.25 * alpha)),
                   style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(Theme.verdigris.opacity(0.55 * alpha)),
                   style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(Color(hex: 0xc8f0ff).opacity(0.95 * alpha)),
                   style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        if seed % 2 == 0 {                                   // a forking branch
            let m = pts[segs * 2 / 3]
            let fa = atan2(dy, dx) + (seed % 4 == 0 ? 0.7 : -0.7)
            let fl = len * 0.18
            var fork = Path()
            fork.move(to: m)
            fork.addLine(to: CGPoint(x: m.x + cos(fa) * fl, y: m.y + sin(fa) * fl))
            ctx.stroke(fork, with: .color(Color(hex: 0xc8f0ff).opacity(0.8 * alpha)),
                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}

// A bright arc of "current" racing around a rounded-rect border. Layered over the
// electricPanel stroke so every panel looks energized.
struct TravelingCurrent: ViewModifier {
    var corner: CGFloat
    func body(content: Content) -> some View {
        content.overlay(
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .clear, .clear, .clear,
                                Theme.verdigris.opacity(0.0),
                                Color(hex: 0xc8f0ff), Theme.verdigris,
                                Theme.verdigris.opacity(0.0),
                                .clear, .clear, .clear]),
                            center: .center, angle: .degrees(t * 170)),
                        lineWidth: 2.5)
                    .blur(radius: 1.2)
            }
            .allowsHitTesting(false)
        )
    }
}

extension View {
    func travelingCurrent(corner: CGFloat) -> some View { modifier(TravelingCurrent(corner: corner)) }
}

// A light electric "charge" — faint pulsing border + glow. For elements that should
// feel energized without the full panel treatment (e.g. every chapter row).
struct ChargedRow: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.verdigris.opacity(on ? 0.38 : 0.12), lineWidth: 1))
            .shadow(color: Theme.verdigris.opacity(on ? 0.35 : 0.12), radius: on ? 7 : 3)
            .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { on = true } }
    }
}

extension View {
    func charged() -> some View { modifier(ChargedRow()) }
}
