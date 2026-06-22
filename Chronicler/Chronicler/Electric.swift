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

// The x-fractions of the 5 smokestacks in FactorySkyline. SteamOverlay anchors its
// plumes to these so the steam visibly puffs out of the chimney mouths.
let kFactoryStackX: [CGFloat] = [0.09, 0.30, 0.50, 0.69, 0.90]
// Chimney-mouth height as a fraction of screen height (just above the skyline). The
// skyline is pinned to the bottom ~210pt; the tall stacks rise above the low buildings,
// so the mouths sit roughly here. Steam starts climbing from this y.
private let kFactoryMouthYFrac: CGFloat = 0.78

// Steampunk-only: lush rising STEAM puffing out of the factory smokestacks. ~9 soft
// white/cream plumes, each a blurred radial-gradient blob that rises from a chimney
// mouth, growing and fading as it climbs, then loops. Fully deterministic from a
// continuous TimelineView clock (no Date()/RNG) so it's resume-safe; each plume is varied
// purely by its index. Non-interactive — drifts up over content. Peak opacity reads
// clearly so the theme looks genuinely steamy.
struct SteamOverlay: View {
    // 9 plumes mapped onto the 5 stacks: the wider central stacks emit two each.
    // (stackIndex, lateral offset within the mouth in x-fractions).
    private let emitters: [(stack: Int, dx: CGFloat)] = [
        (0,  0.0),
        (1, -0.025), (1, 0.03),
        (2, -0.03),  (2, 0.03),
        (3, -0.025), (3, 0.025),
        (4,  0.0),
        (2,  0.0),   // an extra central wisp
    ]
    private var count: Int { emitters.count }

    var body: some View {
        if Theme.mode != .steampunk {
            Color.clear
        } else {
            GeometryReader { geo in
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<count, id: \.self) { i in
                            plume(i, in: geo.size, t: t)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // Normal compositing (not .screen) so the soft white plumes read as distinct,
            // billowing steam over the warm brass void rather than a faint glow.
        }
    }

    // One plume: rises from its chimney mouth through a looping 0..1 cycle, fading in low,
    // peaking mid-rise, fading out high; scales up as it climbs so it billows. Phase/size
    // vary per i; horizontal anchor is the assigned smokestack.
    @ViewBuilder
    private func plume(_ i: Int, in size: CGSize, t: Double) -> some View {
        let fi = Double(i)
        // Horizontal anchor: the assigned smokestack mouth, plus a small lateral offset
        // and gentle drift so paired plumes don't perfectly overlap.
        let e = emitters[i]
        let wobble = 0.03 * sin(t * (0.25 + 0.04 * fi) + fi)  // gentle horizontal drift
        let xFrac = kFactoryStackX[e.stack] + e.dx + CGFloat(wobble)
        let period = 9.0 + Double(i % 4) * 2.5                // 9..16.5s rise loops
        let phase = fi / Double(count)                        // staggered starts
        let cycle = ((t / period) + phase).truncatingRemainder(dividingBy: 1)

        // Vertical travel: start at the chimney mouth, climb past the top of the screen.
        let mouthY = kFactoryMouthYFrac
        let y = size.height * (mouthY - (mouthY + 0.2) * CGFloat(cycle))
        let x = size.width * xFrac

        // Envelope: fade in, hold bright through the middle, fade out near the top.
        let fade = sin(cycle * .pi)                           // 0→1→0 over the cycle
        let opacity = 0.6 * pow(fade, 0.6)
        // Grow as it rises (billowing), with size also varied per plume.
        let baseD = size.width * (0.28 + 0.09 * Double(i % 3))
        let diameter = baseD * (0.55 + 0.9 * cycle)

        Circle()
            .fill(RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0xFFFDF6).opacity(0.85),  // bright near-white core
                    Color(hex: 0xF4ECDC).opacity(0.4),   // warm cream mid
                    Color(hex: 0xF4ECDC).opacity(0.12),
                    .clear]),
                center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
            .blur(radius: 22)
            .opacity(opacity)
            .position(x: x, y: y)
    }
}

// Steampunk-only: an OLD-TIMEY INDUSTRIAL FACTORY SKYLINE pinned to the bottom of the
// screen. A dark silhouette (low factory buildings + 5 tall smokestacks + a big cogwheel)
// drawn with a single Canvas: a near-black fill with a thin warm rim, topped by a soft
// warm glow so it reads against the brass void. The 5 stacks sit at `kFactoryStackX` so
// SteamOverlay's plumes line up with the chimney mouths. Non-interactive; sits behind the
// Landing content. Mirrors the web factory skyline.
struct FactorySkyline: View {
    var body: some View {
        if Theme.mode != .steampunk {
            Color.clear
        } else {
            GeometryReader { geo in
                let w = geo.size.width
                let skyH: CGFloat = 210
                ZStack(alignment: .bottom) {
                    Color.clear
                    Canvas { ctx, size in draw(ctx, size) }
                        .frame(width: w, height: skyH)
                        // Soft warm glow on top so the silhouette reads against the field.
                        .shadow(color: Color(hex: 0xC8731E).opacity(0.45), radius: 18, y: -2)
                        .shadow(color: Color(hex: 0x5A3414).opacity(0.5), radius: 6, y: -1)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let fill = GraphicsContext.Shading.color(Color(hex: 0x0C0702))
        let rim  = Color(hex: 0x5A3414)

        // The skyline mouth height (top of the stacks) — keep in sync with the steam
        // mouth fraction. Stacks rise to ~22% of the skyline band from the top.
        let stackTop = h * 0.10
        let stackBottom = h
        let stackW = w * 0.05

        var solids: [Path] = []

        // --- Low factory buildings across the bottom (varied heights). ---
        let buildings: [(x: CGFloat, w: CGFloat, top: CGFloat)] = [
            (0.00, 0.20, 0.58), (0.18, 0.16, 0.46), (0.33, 0.16, 0.66),
            (0.47, 0.18, 0.50), (0.62, 0.15, 0.62), (0.74, 0.16, 0.44),
            (0.86, 0.16, 0.56),
        ]
        for b in buildings {
            let bx = w * b.x, bw = w * b.w, bt = h * b.top
            var p = Path(CGRect(x: bx, y: bt, width: bw, height: h - bt))
            // A couple of stepped roof ridges for an industrial silhouette.
            p.addRect(CGRect(x: bx + bw * 0.1, y: bt - h * 0.06, width: bw * 0.3, height: h * 0.06))
            solids.append(p)
        }

        // --- 5 tall smokestacks at the canonical x-fractions, each with a flared cap. ---
        for fx in kFactoryStackX {
            let cx = w * fx
            // Slightly tapered chimney body.
            var body = Path()
            let halfTop = stackW * 0.5, halfBot = stackW * 0.62
            body.move(to: CGPoint(x: cx - halfBot, y: stackBottom))
            body.addLine(to: CGPoint(x: cx - halfTop, y: stackTop + h * 0.05))
            body.addLine(to: CGPoint(x: cx + halfTop, y: stackTop + h * 0.05))
            body.addLine(to: CGPoint(x: cx + halfBot, y: stackBottom))
            body.closeSubpath()
            solids.append(body)
            // Flared cap (wider lip at the mouth).
            let capH = h * 0.05, capHalf = stackW * 0.72
            solids.append(Path(CGRect(x: cx - capHalf, y: stackTop, width: capHalf * 2, height: capH)))
        }

        // --- Big cogwheel sitting between the stacks (left-of-center). ---
        let cogCx = w * 0.20, cogCy = h * 0.62, cogR = h * 0.24
        solids.append(cogwheel(center: CGPoint(x: cogCx, y: cogCy), radius: cogR, teeth: 12))

        // Fill all solids, then stroke a thin warm rim on top.
        for p in solids { ctx.fill(p, with: fill) }
        for p in solids {
            ctx.stroke(p, with: .color(rim.opacity(0.85)), lineWidth: 1.2)
        }
        // Hub hole in the cog (punch a brass ring so it reads as a gear).
        let hubR = cogR * 0.34
        ctx.stroke(Path(ellipseIn: CGRect(x: cogCx - hubR, y: cogCy - hubR, width: hubR * 2, height: hubR * 2)),
                   with: .color(rim.opacity(0.9)), lineWidth: 1.4)
    }

    // A gear silhouette: an outer ring with `teeth` trapezoidal teeth.
    private func cogwheel(center c: CGPoint, radius r: CGFloat, teeth: Int) -> Path {
        var p = Path()
        let inner = r * 0.78
        let toothHalf = (.pi / Double(teeth)) * 0.5   // angular half-width of a tooth tip
        for k in 0..<teeth {
            let a0 = (Double(k) / Double(teeth)) * 2 * .pi
            let a1 = a0 + toothHalf
            let a2 = a0 + (.pi / Double(teeth)) - toothHalf
            let a3 = a0 + (.pi / Double(teeth))
            func pt(_ ang: Double, _ rad: CGFloat) -> CGPoint {
                CGPoint(x: c.x + cos(ang) * rad, y: c.y + sin(ang) * rad)
            }
            if k == 0 { p.move(to: pt(a0, r)) } else { p.addLine(to: pt(a0, r)) }
            p.addLine(to: pt(a1, r))            // tooth outer edge
            p.addLine(to: pt(a2, inner))        // dip to valley
            p.addLine(to: pt(a3, inner))
        }
        p.closeSubpath()
        return p
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
