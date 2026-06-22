import SwiftUI

// Full-screen animated electricity: roving lightning bolts that strobe + flicker,
// plus drifting glow nodes. Sits behind content (additive screen blend) so the whole
// app looks like it's buzzing with current. Deterministic from time (no RNG) so it's
// resume-safe and cheap — one offscreen-rendered Canvas per frame.
struct ElectricBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        // No electricity in steampunk or garden — those backgrounds stay quiet voids.
        if Theme.mode != .tesla {
            Color.clear
        } else {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in draw(ctx, size, t) }
                    .blendMode(.screen)
                    .drawingGroup()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
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

        // Strobing lightning bolts — sparse: fewer bolts + slower, briefer strikes (~¼ as much).
        let bolts = max(1, Int(2.5 * intensity))
        for k in 0..<bolts {
            let phase = Double(k) * 1.7
            let strobe = pow(max(0, sin(t * (0.9 + Double(k % 3) * 0.35) + phase)), 12)  // rare, brief bursts
            let flick = 0.55 + 0.45 * sin(t * 42 + phase)                                // fast flicker while lit
            let alpha = strobe * (0.35 + 0.65 * flick) * min(1.3, intensity)
            if alpha < 0.02 { continue }
            let a = CGPoint(x: w * (0.5 + 0.52 * sin(t * 0.13 + phase)),
                            y: h * (0.10 + 0.12 * sin(t * 0.21 + phase * 1.3)))
            let b = CGPoint(x: w * (0.5 + 0.52 * sin(t * 0.11 + phase + 2.0)),
                            y: h * (0.80 + 0.18 * sin(t * 0.17 + phase * 0.7)))
            bolt(ctx, a, b, t, k, alpha)
        }
    }

    // A natural lightning bolt: a fractal (midpoint-displaced) channel rendered as
    // stacked glow layers up to a white-hot core, with a few jagged forks branching off.
    private func bolt(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ t: Double, _ seed: Int, _ alpha: Double) {
        let len = max(1, hypot(b.x - a.x, b.y - a.y))
        let pts = jagged(a, b, rough: len * 0.13, levels: 5, seed: seed, t: t)
        strokeBolt(ctx, pts, alpha: alpha, scale: 1)

        let dir0 = atan2(b.y - a.y, b.x - a.x)
        let forks = 2 + seed % 2
        for k in 0..<forks {
            let idx = min(pts.count - 2, Int(Double(pts.count) * (0.35 + 0.2 * Double(k))))
            guard idx > 0 else { continue }
            let base = pts[idx]
            let dir = dir0 + (k % 2 == 0 ? 0.8 : -0.8) + sin(t * 2 + Double(seed + k)) * 0.25
            let fl = len * (0.24 - 0.05 * Double(k))
            let end = CGPoint(x: base.x + cos(dir) * fl, y: base.y + sin(dir) * fl)
            strokeBolt(ctx, jagged(base, end, rough: fl * 0.2, levels: 3, seed: seed * 7 + k, t: t),
                       alpha: alpha * 0.8, scale: 0.6)
        }
    }

    // Recursive midpoint displacement → a jagged, organic lightning channel.
    private func jagged(_ a: CGPoint, _ b: CGPoint, rough: Double, levels: Int, seed: Int, t: Double) -> [CGPoint] {
        var pts = [a, b]
        var disp = rough
        for level in 0..<levels {
            var next: [CGPoint] = [pts[0]]
            for i in 0..<(pts.count - 1) {
                let p0 = pts[i], p1 = pts[i + 1]
                let sx = p1.x - p0.x, sy = p1.y - p0.y
                let sl = max(1, hypot(sx, sy))
                let nx = -sy / sl, ny = sx / sl
                let h = sin(Double(seed) * 12.9 + Double(i + level * 7) * 78.233 + t * 2.5)
                let off = h * disp
                next.append(CGPoint(x: (p0.x + p1.x) / 2 + nx * off, y: (p0.y + p1.y) / 2 + ny * off))
                next.append(p1)
            }
            pts = next
            disp *= 0.52
        }
        return pts
    }

    // Stacked strokes: wide soft halo → blue glow → bright channel → white-hot core.
    private func strokeBolt(_ ctx: GraphicsContext, _ pts: [CGPoint], alpha: Double, scale: Double) {
        guard pts.count > 1 else { return }
        var path = Path()
        path.move(to: pts[0]); for p in pts.dropFirst() { path.addLine(to: p) }
        ctx.stroke(path, with: .color(Theme.verdigris.opacity(0.10 * alpha)),
                   style: StrokeStyle(lineWidth: 16 * scale, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(Theme.verdigris.opacity(0.32 * alpha)),
                   style: StrokeStyle(lineWidth: 7 * scale, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(Color(hex: 0x9fe0ff).opacity(0.9 * alpha)),
                   style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(Color.white.opacity(0.95 * alpha)),
                   style: StrokeStyle(lineWidth: 1.3 * scale, lineCap: .round, lineJoin: .round))
    }
}

// Full themed backdrop for every screen. Steampunk: a quiet warm brass void (just the
// base color — no electricity). Tesla: a cold blue-black field with a soft cyan radial
// glow and a faint circuit grid, with the roving lightning on top. Replaces the old
// `Theme.bg + ElectricBackground` pair so the whole identity branches in one place.
struct ThemedBackground: View {
    var intensity: Double = 1.0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if Theme.mode == .tesla {
                // Cyan radial glow rising from center.
                RadialGradient(
                    colors: [Theme.verdigris.opacity(0.16), Theme.bg2.opacity(0.0)],
                    center: .center, startRadius: 0, endRadius: 520)
                    .ignoresSafeArea()
                CircuitGrid()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else if Theme.mode == .garden {
                // Garden: a dark green field with a soft GREEN radial bloom rising from
                // center. No grid, no lightning — just a quiet verdant glow.
                RadialGradient(
                    colors: [Color(hex: 0x7cc24a).opacity(0.20), Theme.bg2.opacity(0.0)],
                    center: .center, startRadius: 0, endRadius: 540)
                    .ignoresSafeArea()
            }
            ElectricBackground(intensity: intensity)
        }
    }
}

// A faint cyan circuit grid: thin lattice lines with brighter "node" dots at a subset
// of intersections. Cheap single-pass Canvas, static (no animation needed).
private struct CircuitGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 46
            let line = Theme.verdigris.opacity(0.06)
            var x: CGFloat = 0
            while x <= size.width { ctx.stroke(Path { $0.move(to: .init(x: x, y: 0)); $0.addLine(to: .init(x: x, y: size.height)) }, with: .color(line), lineWidth: 0.6); x += step }
            var y: CGFloat = 0
            while y <= size.height { ctx.stroke(Path { $0.move(to: .init(x: 0, y: y)); $0.addLine(to: .init(x: size.width, y: y)) }, with: .color(line), lineWidth: 0.6); y += step }
            // Sparse brighter nodes at deterministic intersections.
            var iy: CGFloat = step
            var row = 0
            while iy < size.height {
                var ix: CGFloat = step
                var col = 0
                while ix < size.width {
                    if (row + col) % 3 == 0 {
                        let r: CGFloat = 1.6
                        ctx.fill(Path(ellipseIn: CGRect(x: ix - r, y: iy - r, width: r * 2, height: r * 2)),
                                 with: .color(Theme.verdigris.opacity(0.22)))
                    }
                    ix += step; col += 1
                }
                iy += step; row += 1
            }
        }
        .blendMode(.screen)
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
        // Steampunk + Garden: steady edged row, no pulsing charge. Tesla: pulses.
        if Theme.mode != .tesla {
            content
                .overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.glow.opacity(0.22), lineWidth: 1))
                .shadow(color: Theme.glow.opacity(0.18), radius: 4)
        } else {
            content
                .overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.glow.opacity(on ? 0.38 : 0.12), lineWidth: 1))
                .shadow(color: Theme.glow.opacity(on ? 0.35 : 0.12), radius: on ? 7 : 3)
                .onAppear { withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { on = true } }
        }
    }
}

extension View {
    func charged() -> some View { modifier(ChargedRow()) }
}
