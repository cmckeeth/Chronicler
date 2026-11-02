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

// Steampunk-only: LARGE brass cogs in the corners, slowly + continuously rotating
// (alternating CW/CCW), at low opacity so they sit as subtle background machinery.
// Mirrors the web app's rotating corner cogs (~4 cogs, ~120-150pt, opacity ~.18-.22,
// ~15-36s per turn). Driven by a single TimelineView clock so it's resume-safe + cheap.
struct CornerCogs: View {
    // (x-fraction, y-fraction, diameter pt, period s, clockwise, teeth, opacity).
    private let cogs: [(x: CGFloat, y: CGFloat, d: CGFloat, period: Double, cw: Bool, teeth: Int, op: Double)] = [
        (0.02, 0.04, 150, 30, true,  14, 0.20),   // top-left
        (0.98, 0.06, 120, 22, false, 12, 0.18),   // top-right
        (0.04, 0.96, 130, 36, false, 13, 0.19),   // bottom-left
        (0.97, 0.94, 140, 18, true,  14, 0.22),   // bottom-right
    ]

    var body: some View {
        if Theme.mode != .steampunk {
            Color.clear
        } else {
            GeometryReader { geo in
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(cogs.indices, id: \.self) { i in
                            let c = cogs[i]
                            let turns = (t / c.period) * (c.cw ? 1 : -1)
                            Cog(teeth: c.teeth)
                                .fill(Theme.borderBrass, style: FillStyle(eoFill: true))
                                .frame(width: c.d, height: c.d)
                                .opacity(c.op)
                                .rotationEffect(.degrees(turns * 360))
                                .position(x: geo.size.width * c.x, y: geo.size.height * c.y)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

// A gear Shape: an outer ring of trapezoidal teeth with a punched-out hub hole (even-odd).
struct Cog: Shape {
    var teeth: Int = 13

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let inner = r * 0.78
        let toothHalf = (.pi / Double(teeth)) * 0.5
        var p = Path()
        func pt(_ ang: Double, _ rad: CGFloat) -> CGPoint {
            CGPoint(x: c.x + cos(ang) * rad, y: c.y + sin(ang) * rad)
        }
        for k in 0..<teeth {
            let a0 = (Double(k) / Double(teeth)) * 2 * .pi
            let a1 = a0 + toothHalf
            let a2 = a0 + (.pi / Double(teeth)) - toothHalf
            let a3 = a0 + (.pi / Double(teeth))
            if k == 0 { p.move(to: pt(a0, r)) } else { p.addLine(to: pt(a0, r)) }
            p.addLine(to: pt(a1, r))
            p.addLine(to: pt(a2, inner))
            p.addLine(to: pt(a3, inner))
        }
        p.closeSubpath()
        // Hub hole — even-odd fill punches it out so the cog reads as a ring + spokes.
        let hubR = r * 0.30
        p.addEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2))
        return p
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
            (0.00, 0.20, 0.58), (0.18, 0.17, 0.46), (0.34, 0.17, 0.66),
            (0.50, 0.18, 0.50), (0.67, 0.16, 0.62), (0.83, 0.17, 0.44),
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
            } else if Theme.mode == .academia {
                // Dark Academia: warm brass lamplight from above, a faint green pool low,
                // and rain streaking down the windows.
                RadialGradient(
                    colors: [Theme.brass.opacity(0.14), Theme.bg2.opacity(0.0)],
                    center: .top, startRadius: 0, endRadius: 600)
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.verdigris.opacity(0.10), Theme.bg.opacity(0.0)],
                    center: .bottom, startRadius: 0, endRadius: 420)
                    .ignoresSafeArea()
                RainOverlay()
            } else if Theme.mode == .noir {
                // Blackletter Noir: a blood rose-window glow high above, a heavy cathedral
                // tunnel vignette closing the edges, a low ox-blood ember on the floor,
                // thick drifting fog, and embers rising from the dark.
                RadialGradient(
                    colors: [Theme.verdigris.opacity(0.18), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.10), startRadius: 0, endRadius: 360)
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.84)],
                    center: .center, startRadius: 50, endRadius: 700)
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.verdigris.opacity(0.17), Theme.bg.opacity(0.0)],
                    center: .bottom, startRadius: 0, endRadius: 470)
                    .ignoresSafeArea()
                FogOverlay()
                EmberOverlay()
            } else if Theme.mode == .west {
                // Wild West: a low sun burning on the horizon, mesas cut out against it,
                // hanging dust in the air and tumbleweeds rolling across the flats.
                RadialGradient(
                    colors: [Color(hex: 0xf08a30).opacity(0.42), Color(hex: 0x9c4418).opacity(0.16),
                             Theme.bg.opacity(0.0)],
                    center: UnitPoint(x: 0.5, y: 0.82), startRadius: 0, endRadius: 560)
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.55)],
                    center: .center, startRadius: 120, endRadius: 720)
                    .ignoresSafeArea()
                MesaSkyline()
                DustOverlay()
                TumbleweedOverlay()
            } else if Theme.mode == .neon {
                // Vaporwave: a magenta/indigo sky bleeding into a banded sun on the
                // horizon, a wireframe grid scrolling toward the viewer, palms in
                // silhouette, and a slow CRT flicker over the lot.
                LinearGradient(colors: [Color(hex: 0x2a0b4a), Color(hex: 0x7a1170).opacity(0.65),
                                        Color(hex: 0xff4fd8).opacity(0.22)],
                               startPoint: .top, endPoint: .init(x: 0.5, y: 0.62))
                    .ignoresSafeArea()
                NeonSunGrid()
                ScanlineOverlay()
            } else if Theme.mode == .forge {
                // Obsidian with heat rising: a molten pool churning along the bottom,
                // glowing fissures cracking the rock, and sparks spitting upward.
                RadialGradient(
                    colors: [Color(hex: 0xff6a12).opacity(0.34), Color(hex: 0x8c1f04).opacity(0.14),
                             Theme.bg.opacity(0.0)],
                    center: UnitPoint(x: 0.5, y: 1.02), startRadius: 0, endRadius: 620)
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.62)],
                    center: .center, startRadius: 90, endRadius: 700)
                    .ignoresSafeArea()
                LavaFissures()
                SparkOverlay()
            } else if Theme.mode == .ransom {
                // Photocopied paper: toner grain, halftone dots, a couple of streaks, and
                // tape strips at the corners. Light, flat, deliberately cheap-looking.
                XeroxPaper()
            } else if Theme.mode == .abyss {
                // The deep sea: water fading from dim teal to black, with light shafts,
                // marine snow, jellyfish, a lure, and — now and then — eyes.
                LinearGradient(colors: [Color(hex: 0x041a2a), Color.black],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                AbyssDepths()
            } else if Theme.mode == .arcade {
                // Attract mode on a black cabinet screen.
                ArcadeScreen()
            }
            ElectricBackground(intensity: intensity)
        }
    }
}

// Wild-West-only: the horizon — a row of mesas/buttes and a few saguaro silhouettes cut
// flat and black against the setting sun, pinned to the bottom of the screen.
struct MesaSkyline: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let base = h                       // ground line sits at the screen bottom
                let silhouette = Color(hex: 0x1a0f07)

                // Far mesas: flat-topped blocks with sloped shoulders.
                func mesa(_ cx: CGFloat, _ width: CGFloat, _ height: CGFloat, _ shade: Double) {
                    var p = Path()
                    let l = cx - width / 2, r = cx + width / 2, top = base - height
                    p.move(to: CGPoint(x: l, y: base))
                    p.addLine(to: CGPoint(x: l + width * 0.18, y: top))
                    p.addLine(to: CGPoint(x: r - width * 0.14, y: top))
                    p.addLine(to: CGPoint(x: r, y: base))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(silhouette.opacity(shade)))
                }
                mesa(w * 0.10, w * 0.40, h * 0.085, 0.85)
                mesa(w * 0.55, w * 0.34, h * 0.062, 0.8)
                mesa(w * 0.95, w * 0.32, h * 0.10, 0.9)

                // A saguaro: trunk + two raised arms.
                func saguaro(_ cx: CGFloat, _ scale: CGFloat) {
                    let trunkW = 11 * scale, trunkH = 96 * scale
                    let armW = 8 * scale
                    var p = Path()
                    p.addRoundedRect(in: CGRect(x: cx - trunkW / 2, y: base - trunkH,
                                                width: trunkW, height: trunkH),
                                     cornerSize: CGSize(width: trunkW / 2, height: trunkW / 2))
                    // left arm: out then up
                    p.addRoundedRect(in: CGRect(x: cx - 30 * scale, y: base - trunkH * 0.62,
                                                width: armW, height: trunkH * 0.42),
                                     cornerSize: CGSize(width: armW / 2, height: armW / 2))
                    p.addRoundedRect(in: CGRect(x: cx - 30 * scale, y: base - trunkH * 0.62,
                                                width: 30 * scale, height: armW),
                                     cornerSize: CGSize(width: armW / 2, height: armW / 2))
                    // right arm: shorter, higher
                    p.addRoundedRect(in: CGRect(x: cx + 22 * scale, y: base - trunkH * 0.78,
                                                width: armW, height: trunkH * 0.34),
                                     cornerSize: CGSize(width: armW / 2, height: armW / 2))
                    p.addRoundedRect(in: CGRect(x: cx, y: base - trunkH * 0.78,
                                                width: 26 * scale, height: armW),
                                     cornerSize: CGSize(width: armW / 2, height: armW / 2))
                    ctx.fill(p, with: .color(silhouette.opacity(0.85)))
                }
                saguaro(w * 0.30, 0.62)
                saguaro(w * 0.78, 0.45)

                // Flat desert floor closing off the bottom.
                ctx.fill(Path(CGRect(x: 0, y: base - 10, width: w, height: 40)),
                         with: .color(silhouette.opacity(0.9)))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Wild-West-only: fine dust hanging in the low sun — slow motes drifting sideways.
struct DustOverlay: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                for i in 0..<70 {
                    let fy = Double((i * 61) % 1000) / 1000.0
                    let speed = 12.0 + Double((i * 29) % 26)
                    let x = CGFloat((t * speed + Double(i) * 91).truncatingRemainder(dividingBy: Double(w + 60))) - 30
                    let bob = CGFloat(sin(t * 0.6 + Double(i)) * 6)
                    let y = CGFloat(fy) * h + bob
                    let r: CGFloat = 1 + CGFloat(i % 3)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(Color(hex: 0xe8c489).opacity(0.16)))
                }
            }
            .blendMode(.screen)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Wild-West-only: tumbleweeds rolling across the flats — tangled balls of line that
// spin as they travel and bounce along the ground. Deterministic from the clock.
struct TumbleweedOverlay: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                for k in 0..<3 {
                    let period = 17.0 + Double(k) * 7          // seconds to cross
                    let phase = ((t / period) + Double(k) * 0.37).truncatingRemainder(dividingBy: 1)
                    let radius: CGFloat = 15 - CGFloat(k) * 3
                    let x = CGFloat(phase) * (w + 160) - 80
                    // hops along the ground; higher weeds sit further back up the screen
                    let ground = h - 14 - CGFloat(k) * 16
                    let hop = CGFloat(abs(sin(phase * .pi * 9))) * (18 - CGFloat(k) * 4)
                    let cy = ground - hop - radius
                    let spin = phase * .pi * 2 * 7

                    // A tangled ball of brush: several ragged closed loops at different
                    // radii, each with per-vertex jitter, so it reads as a knot of twigs
                    // rather than a wheel. Jitter is a fixed function of the indices, so
                    // the shape is stable across frames and resume-safe.
                    for ring in 0..<4 {
                        let ringScale = CGFloat(0.45 + 0.2 * Double(ring))
                        let tilt = spin * (ring % 2 == 0 ? 1 : -0.8) + Double(ring)
                        var p = Path()
                        let steps = 13
                        for j in 0...steps {
                            let a = tilt + Double(j) * (2 * .pi / Double(steps))
                            let jitter = 0.72 + 0.5 * abs(sin(Double(j) * 3.1 + Double(ring) * 1.7 + Double(k)))
                            let rr = radius * ringScale * CGFloat(jitter)
                            let pt = CGPoint(x: x + rr * CGFloat(cos(a)), y: cy + rr * CGFloat(sin(a)) * 0.9)
                            if j == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                        p.closeSubpath()
                        ctx.stroke(p, with: .color(Color(hex: 0x8a6231).opacity(0.75)), lineWidth: 1.2)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}


// ── Neon Sunset FX ───────────────────────────────────────────────────────────

// Vaporwave-only: a banded sun sitting on the horizon with a wireframe grid floor
// scrolling toward the viewer, plus palm silhouettes flanking it. The grid is drawn in
// perspective: rows are spaced by a squared progression so they bunch at the horizon,
// and the whole set slides forward on a loop. Deterministic from the clock.
struct NeonSunGrid: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let horizon = h * 0.62

                // Sun: a disc clipped to horizontal bands, sinking into the horizon.
                let sunR = min(w, h) * 0.20
                let cx = w / 2, cy = horizon - sunR * 0.28
                var disc = Path(ellipseIn: CGRect(x: cx - sunR, y: cy - sunR,
                                                  width: sunR * 2, height: sunR * 2))
                ctx.fill(disc, with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xffe14f), Color(hex: 0xff4fd8), Color(hex: 0x9c2bff)]),
                    startPoint: CGPoint(x: cx, y: cy - sunR), endPoint: CGPoint(x: cx, y: cy + sunR)))
                // Band gaps widen toward the bottom of the disc.
                var band = 0.0
                var i = 0
                while band < sunR * 2 {
                    let gap = 3.0 + Double(i) * 1.5
                    let y = cy - sunR + band
                    ctx.fill(Path(CGRect(x: cx - sunR, y: y, width: sunR * 2, height: gap * 0.55)),
                             with: .color(Color(hex: 0x150726).opacity(0.9)))
                    band += gap + 6
                    i += 1
                }
                disc = Path(ellipseIn: CGRect(x: cx - sunR, y: cy - sunR,
                                              width: sunR * 2, height: sunR * 2))
                ctx.stroke(disc, with: .color(Color(hex: 0xff8ce6).opacity(0.9)), lineWidth: 2)

                // Ground below the horizon reads darker so the grid pops.
                ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
                         with: .linearGradient(
                            Gradient(colors: [Color(hex: 0x1b0733), Color(hex: 0x0d0418)]),
                            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))

                let grid = Color(hex: 0x22e0ff)
                // Horizontal rows: perspective spacing, scrolling forward on a 2.6s loop.
                let phase = (t / 2.6).truncatingRemainder(dividingBy: 1)
                for k in 0..<16 {
                    let p = (Double(k) + phase) / 16                 // 0 at horizon → 1 at viewer
                    let y = horizon + (h - horizon) * p * p          // squared = perspective bunching
                    if y > h { continue }
                    ctx.stroke(Path { pth in
                        pth.move(to: CGPoint(x: 0, y: y)); pth.addLine(to: CGPoint(x: w, y: y))
                    }, with: .color(grid.opacity(0.10 + 0.5 * p)), lineWidth: 0.6 + 1.4 * p)
                }
                // Verticals: fan out from a vanishing point at the horizon centre.
                for k in -9...9 {
                    let xBottom = cx + CGFloat(k) * (w / 6)
                    ctx.stroke(Path { pth in
                        pth.move(to: CGPoint(x: cx, y: horizon))
                        pth.addLine(to: CGPoint(x: xBottom, y: h))
                    }, with: .color(grid.opacity(0.30)), lineWidth: 1)
                }
                // Horizon glow line.
                ctx.stroke(Path { pth in
                    pth.move(to: CGPoint(x: 0, y: horizon)); pth.addLine(to: CGPoint(x: w, y: horizon))
                }, with: .color(Color(hex: 0xff8ce6).opacity(0.85)), lineWidth: 2)

                // Palms: a leaning trunk with drooping fronds, flanking the sun.
                func palm(_ baseX: CGFloat, _ scale: CGFloat, _ flip: CGFloat) {
                    let baseY = horizon + 6
                    let hgt = min(w, h) * 0.26 * scale
                    var trunk = Path()
                    trunk.move(to: CGPoint(x: baseX, y: baseY))
                    trunk.addQuadCurve(to: CGPoint(x: baseX + 16 * scale * flip, y: baseY - hgt),
                                       control: CGPoint(x: baseX + 2 * scale * flip, y: baseY - hgt * 0.6))
                    ctx.stroke(trunk, with: .color(Color(hex: 0x120423)), lineWidth: 4 * scale)
                    let topX = baseX + 16 * scale * flip, topY = baseY - hgt
                    for f in 0..<6 {
                        let a = Double(f) / 5 * .pi - .pi * 0.08
                        var frond = Path()
                        frond.move(to: CGPoint(x: topX, y: topY))
                        frond.addQuadCurve(
                            to: CGPoint(x: topX + CGFloat(cos(a)) * 34 * scale,
                                        y: topY + CGFloat(abs(sin(a))) * 8 * scale + 16 * scale),
                            control: CGPoint(x: topX + CGFloat(cos(a)) * 22 * scale,
                                             y: topY - 14 * scale))
                        ctx.stroke(frond, with: .color(Color(hex: 0x120423)), lineWidth: 3 * scale)
                    }
                }
                palm(w * 0.13, 1.0, 1)
                palm(w * 0.88, 0.85, -1)
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Neon-only: CRT scanlines plus a slow brightness roll, so the whole screen reads as a
// tube rather than a panel. Cheap: thin dark bands drawn every 3pt.
struct ScanlineOverlay: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var y = 0.0
                while y < size.height {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                             with: .color(Color.black.opacity(0.18)))
                    y += 3
                }
                // The roll: a soft bright band sweeping down the screen every ~7s.
                let rollY = CGFloat((t / 7).truncatingRemainder(dividingBy: 1)) * size.height
                ctx.fill(Path(CGRect(x: 0, y: rollY - 40, width: size.width, height: 80)),
                         with: .linearGradient(
                            Gradient(colors: [Color.white.opacity(0), Color.white.opacity(0.05),
                                              Color.white.opacity(0)]),
                            startPoint: CGPoint(x: 0, y: rollY - 40),
                            endPoint: CGPoint(x: 0, y: rollY + 40)))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// ── Molten Forge FX ──────────────────────────────────────────────────────────

// Forge-only: a churning molten pool along the bottom plus glowing fissures cracking
// up through the rock. The pool surface is a sine sum so it deforms without repeating
// obviously; the fissures pulse on independent periods.
struct LavaFissures: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height

                // Molten pool: a wavy top edge filled with a hot gradient.
                let surface = h * 0.96
                var pool = Path()
                pool.move(to: CGPoint(x: 0, y: h))
                var x = 0.0
                while x <= Double(w) {
                    let y = surface
                        + sin(x / 70 + t * 0.7) * 7
                        + sin(x / 33 - t * 1.1) * 4
                    pool.addLine(to: CGPoint(x: x, y: y))
                    x += 6
                }
                pool.addLine(to: CGPoint(x: w, y: h))
                pool.closeSubpath()
                ctx.fill(pool, with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xffd23f), Color(hex: 0xff6a12), Color(hex: 0xb52200)]),
                    startPoint: CGPoint(x: 0, y: surface - 10), endPoint: CGPoint(x: 0, y: h)))
                ctx.stroke(pool, with: .color(Color(hex: 0xffe9a8).opacity(0.8)), lineWidth: 1.5)

                // Fissures: jagged cracks climbing from the pool, breathing on their own
                // periods so the rock looks alive rather than animated in lockstep.
                let fissureX: [CGFloat] = [0.06, 0.17, 0.23, 0.38, 0.52, 0.61, 0.74, 0.83, 0.94]
                for (k, fxFrac) in fissureX.enumerated() {
                    let fx = w * fxFrac
                    let period = 2.2 + Double(k % 4) * 0.9
                    let pulse = 0.35 + 0.65 * (0.5 - 0.5 * cos(t / period * 2 * .pi))
                    let len = h * CGFloat(0.05 + 0.05 * Double(k % 4))
                    var crack = Path()
                    crack.move(to: CGPoint(x: fx, y: surface))
                    var yy = surface
                    var xx = fx
                    var seg = 0
                    while yy > surface - len {
                        yy -= 14
                        xx += CGFloat(sin(Double(seg) * 2.3 + Double(k)) * 9)
                        crack.addLine(to: CGPoint(x: xx, y: yy))
                        seg += 1
                    }
                    ctx.stroke(crack, with: .color(Color(hex: 0xff6a12).opacity(0.22 * pulse)),
                               style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    ctx.stroke(crack, with: .color(Color(hex: 0xffb04a).opacity(0.75 * pulse)),
                               style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    ctx.stroke(crack, with: .color(Color(hex: 0xffe9a8).opacity(0.9 * pulse)),
                               style: StrokeStyle(lineWidth: 1, lineCap: .round))
                }
            }
            .blendMode(.screen)
            .drawingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Forge-only: sparks spitting up off the pool, rising fast, cooling from white to red
// and fading. Deterministic per index so it survives resume.
struct SparkOverlay: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let span = Double(h * 0.8)
                for i in 0..<40 {
                    let fx = Double((i * 83) % 1000) / 1000.0
                    let speed = 110.0 + Double((i * 47) % 130)
                    let prog = (t * speed + Double(i) * 37).truncatingRemainder(dividingBy: span)
                    let life = 1 - prog / span
                    let sway = sin(t * 1.6 + Double(i)) * 14
                    let x = CGFloat(fx) * w + CGFloat(sway)
                    let y = h * 0.96 - CGFloat(prog)
                    let r = CGFloat(1 + (i % 3))
                    // hot core fading to red as it climbs
                    let hot = Color(hex: 0xffe9a8).opacity(life * 0.95)
                    let cool = Color(hex: 0xff3c00).opacity(life * 0.5)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2.6, height: r * 2.6)),
                             with: .color(cool))
                    ctx.fill(Path(ellipseIn: CGRect(x: x + r * 0.6, y: y + r * 0.6,
                                                    width: r, height: r)), with: .color(hot))
                }
            }
            .blendMode(.screen)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// ── Ransom Note FX ───────────────────────────────────────────────────────────

// Ransom-only: the page itself. Halftone dot screen, toner streaks down the sheet, and
// two strips of tape at the corners. Static apart from a barely-perceptible tape flutter,
// because photocopies don't animate.
struct XeroxPaper: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Halftone: a dot screen, denser toward the edges like a bad copy.
            var y = 0.0
            var row = 0
            while y < Double(h) {
                var x = (row % 2 == 0) ? 0.0 : 3.0
                while x < Double(w) {
                    let edge = max(abs(x / Double(w) - 0.5), abs(y / Double(h) - 0.5)) * 2
                    let a = 0.03 + 0.09 * edge * edge
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                             with: .color(Color.black.opacity(a)))
                    x += 6
                }
                y += 6
                row += 1
            }
            // Toner streaks: a few vertical smears, the classic dying-drum artefact.
            for k in 0..<5 {
                let sx = w * CGFloat(0.14 + 0.18 * Double(k))
                let sw = CGFloat(6 + (k % 3) * 5)
                ctx.fill(Path(CGRect(x: sx, y: 0, width: sw, height: h)),
                         with: .linearGradient(
                            Gradient(colors: [Color.black.opacity(0.05), Color.black.opacity(0.0),
                                              Color.black.opacity(0.035)]),
                            startPoint: CGPoint(x: sx, y: 0), endPoint: CGPoint(x: sx, y: h)))
            }
            // Tape: translucent strips across two corners, rotated by hand.
            func tape(_ rect: CGRect, _ deg: Double) {
                var path = Path(rect)
                path = path.applying(CGAffineTransform(translationX: -rect.midX, y: -rect.midY)
                    .concatenating(CGAffineTransform(rotationAngle: deg * .pi / 180))
                    .concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY)))
                ctx.fill(path, with: .color(Color(hex: 0xd8d2be).opacity(0.75)))
                ctx.stroke(path, with: .color(Color.black.opacity(0.10)), lineWidth: 1)
            }
            tape(CGRect(x: -26, y: 52, width: 120, height: 26), -38)
            tape(CGRect(x: w - 94, y: h - 96, width: 120, height: 26), -38)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// ── Abyss FX ─────────────────────────────────────────────────────────────────

// Abyss-only: the deep water column. Faint light shafts swaying down from a surface far
// above, marine snow sinking past, jellyfish pulsing their way upward, an anglerfish lure
// bobbing in the lower corner — and every ~14s a pair of enormous amber eyes opens in the
// dark, blinks once, and sinks back. Deterministic from the clock, so it survives resume.
struct AbyssDepths: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let teal = Color(hex: 0x3dffc8), violet = Color(hex: 0xb86bff)

                // Light shafts: wide wedges fanning down from the top, each swaying on its
                // own slow period so they never line up.
                for k in 0..<4 {
                    let sway = CGFloat(sin(t * 0.13 + Double(k) * 1.7)) * w * 0.06
                    let topX = w * CGFloat(0.15 + 0.24 * Double(k)) + sway
                    let spread = w * CGFloat(0.10 + 0.04 * Double(k % 2))
                    var shaft = Path()
                    shaft.move(to: CGPoint(x: topX - 14, y: 0))
                    shaft.addLine(to: CGPoint(x: topX + 14, y: 0))
                    shaft.addLine(to: CGPoint(x: topX + spread + sway * 2, y: h * 0.7))
                    shaft.addLine(to: CGPoint(x: topX - spread + sway * 2, y: h * 0.7))
                    shaft.closeSubpath()
                    let a = 0.05 + 0.025 * sin(t * 0.4 + Double(k))
                    ctx.fill(shaft, with: .linearGradient(
                        Gradient(colors: [teal.opacity(a), teal.opacity(0)]),
                        startPoint: CGPoint(x: topX, y: 0), endPoint: CGPoint(x: topX, y: h * 0.7)))
                }

                // The eyes. Drawn early so the snow and jellyfish drift in front of them.
                let cycle = 14.0
                let phase = t.truncatingRemainder(dividingBy: cycle)
                if phase < 6.5 {
                    // Fade in over 1.5s, hold, blink once at ~3s, fade out over 2s.
                    let env: Double = phase < 1.5 ? phase / 1.5
                        : phase < 4.5 ? 1 : max(0, 1 - (phase - 4.5) / 2)
                    let blink = max(0, 1 - abs(phase - 3.1) / 0.16)       // 0 open → 1 shut
                    let open = CGFloat(1 - 0.94 * min(1, blink))
                    // Each visit surfaces somewhere a little different.
                    let n = floor(t / cycle)
                    let jitter = (n * 0.618).truncatingRemainder(dividingBy: 1)
                    let cx = w * CGFloat(0.38 + 0.24 * jitter)
                    // Below the landing panel, in open water, so they're seen rather than hidden.
                    let cy = h * CGFloat(0.63 + 0.08 * ((n * 0.382).truncatingRemainder(dividingBy: 1)))
                    let eyeW = w * 0.26, eyeH = eyeW * 0.42 * open
                    let gap = w * 0.22
                    let amber = Color(hex: 0xffb020)
                    let a = 0.35 * env
                    // Pupils drift slowly, as if following something.
                    let look = CGFloat(sin(phase * 0.9)) * eyeW * 0.12
                    for side in [-1.0, 1.0] {
                        let ex = cx + CGFloat(side) * gap
                        // Soft halo so they glow rather than sit flat on the water.
                        ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeW, y: cy - eyeW * 0.6,
                                                        width: eyeW * 2, height: eyeW * 1.2)),
                                 with: .radialGradient(
                                    Gradient(colors: [amber.opacity(a * 0.45), amber.opacity(0)]),
                                    center: CGPoint(x: ex, y: cy), startRadius: 0, endRadius: eyeW))
                        // Almond: two arcs meeting at the corners.
                        var eye = Path()
                        eye.move(to: CGPoint(x: ex - eyeW / 2, y: cy))
                        eye.addQuadCurve(to: CGPoint(x: ex + eyeW / 2, y: cy),
                                         control: CGPoint(x: ex, y: cy - eyeH))
                        eye.addQuadCurve(to: CGPoint(x: ex - eyeW / 2, y: cy),
                                         control: CGPoint(x: ex, y: cy + eyeH))
                        eye.closeSubpath()
                        ctx.fill(eye, with: .radialGradient(
                            Gradient(colors: [Color(hex: 0xffe08a).opacity(a), amber.opacity(a),
                                              Color(hex: 0x8a4a00).opacity(a)]),
                            center: CGPoint(x: ex + look, y: cy), startRadius: 0, endRadius: eyeW * 0.55))
                        // Slit pupil, clipped to the lid so it closes with the blink.
                        var lid = ctx
                        lid.clip(to: eye)
                        let pw = eyeW * 0.07, ph = eyeW * 0.5
                        lid.fill(Path(ellipseIn: CGRect(x: ex + look - pw / 2, y: cy - ph / 2,
                                                        width: pw, height: ph)),
                                 with: .color(Color.black.opacity(0.85 * env)))
                    }
                }

                // Marine snow: specks sinking with a sideways wobble.
                for i in 0..<60 {
                    let fx = Double((i * 137) % 1000) / 1000.0
                    let speed = 6.0 + Double((i * 53) % 18)
                    let y = (Double(i) * 61 + t * speed).truncatingRemainder(dividingBy: Double(h) + 20) - 10
                    let x = CGFloat(fx) * w + CGFloat(sin(t * 0.5 + Double(i) * 1.3) * 9)
                    let r = CGFloat(0.7 + Double(i % 4) * 0.45)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: CGFloat(y), width: r * 2, height: r * 2)),
                             with: .color(Color(hex: 0xd4fff2).opacity(0.18 + 0.08 * Double(i % 4))))
                }

                // Jellyfish: a pulsing bell trailing wavy tentacles, rising slowly and
                // wrapping back to the bottom once it clears the top.
                for j in 0..<4 {
                    let scale = CGFloat(0.7 + 0.22 * Double(j % 3))
                    let col = j % 2 == 0 ? violet : teal
                    let travel = Double(h) + 220
                    let prog = (t * (7 + Double(j) * 2.5) + Double(j) * travel / 4)
                        .truncatingRemainder(dividingBy: travel)
                    let by = h + 90 - CGFloat(prog)
                    let bx = w * CGFloat(0.16 + 0.23 * Double(j)) + CGFloat(sin(t * 0.21 + Double(j) * 2)) * 26
                    let pulse = 0.5 + 0.5 * sin(t * 2 * .pi / 2.5 + Double(j) * 1.4)
                    let bw = 38 * scale * CGFloat(1 + 0.14 * pulse)
                    let bh = 26 * scale * CGFloat(1 - 0.12 * pulse)

                    // Glow around the bell.
                    ctx.fill(Path(ellipseIn: CGRect(x: bx - bw * 1.6, y: by - bh * 1.8,
                                                    width: bw * 3.2, height: bh * 3.4)),
                             with: .radialGradient(
                                Gradient(colors: [col.opacity(0.16 + 0.08 * pulse), col.opacity(0)]),
                                center: CGPoint(x: bx, y: by - bh * 0.3), startRadius: 0, endRadius: bw * 1.6))

                    // Tentacles hang from the rim and ripple, more toward the tips.
                    let count = 5
                    for k in 0..<count {
                        let rootX = bx - bw * 0.42 + bw * 0.84 * CGFloat(k) / CGFloat(count - 1)
                        var ten = Path()
                        ten.move(to: CGPoint(x: rootX, y: by))
                        let len = (58 + CGFloat((k * 13) % 22)) * scale
                        var s: CGFloat = 0
                        while s <= 1.0 {
                            let wave = CGFloat(sin(Double(s) * 7 - t * 2.6 + Double(k + j))) * 5 * scale * s
                            ten.addLine(to: CGPoint(x: rootX + wave, y: by + len * s))
                            s += 0.1
                        }
                        ctx.stroke(ten, with: .linearGradient(
                            Gradient(colors: [col.opacity(0.55), col.opacity(0)]),
                            startPoint: CGPoint(x: rootX, y: by), endPoint: CGPoint(x: rootX, y: by + len)),
                            style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                    }

                    // Bell: a dome over a gently scalloped rim.
                    var bell = Path()
                    bell.move(to: CGPoint(x: bx - bw / 2, y: by))
                    bell.addCurve(to: CGPoint(x: bx + bw / 2, y: by),
                                  control1: CGPoint(x: bx - bw / 2, y: by - bh * 1.35),
                                  control2: CGPoint(x: bx + bw / 2, y: by - bh * 1.35))
                    for s in 0..<4 {
                        let x0 = bx + bw / 2 - bw * CGFloat(s) / 4
                        bell.addQuadCurve(to: CGPoint(x: x0 - bw / 4, y: by),
                                          control: CGPoint(x: x0 - bw / 8, y: by + 4 * scale))
                    }
                    bell.closeSubpath()
                    ctx.fill(bell, with: .radialGradient(
                        Gradient(colors: [col.opacity(0.45), col.opacity(0.12)]),
                        center: CGPoint(x: bx, y: by - bh * 0.6), startRadius: 0, endRadius: bw * 0.7))
                    ctx.stroke(bell, with: .color(col.opacity(0.6)), lineWidth: 1)
                }

                // Anglerfish lure: a glowing bead on a faint curved stalk, bobbing low right.
                let lx = w * 0.8 + CGFloat(sin(t * 0.7)) * 6
                let ly = h * 0.8 + CGFloat(sin(t * 1.3)) * 9
                var stalk = Path()
                stalk.move(to: CGPoint(x: w * 0.98, y: h * 0.93))
                stalk.addQuadCurve(to: CGPoint(x: lx, y: ly),
                                   control: CGPoint(x: w * 0.95, y: h * 0.78))
                ctx.stroke(stalk, with: .color(teal.opacity(0.14)), lineWidth: 1.2)
                let flick = 0.75 + 0.25 * sin(t * 4.1) * sin(t * 1.7)
                ctx.fill(Path(ellipseIn: CGRect(x: lx - 26, y: ly - 26, width: 52, height: 52)),
                         with: .radialGradient(
                            Gradient(colors: [teal.opacity(0.4 * flick), teal.opacity(0)]),
                            center: CGPoint(x: lx, y: ly), startRadius: 0, endRadius: 26))
                ctx.fill(Path(ellipseIn: CGRect(x: lx - 3, y: ly - 3, width: 6, height: 6)),
                         with: .color(Color(hex: 0xd4fff2).opacity(0.95 * flick)))
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// ── Arcade FX ────────────────────────────────────────────────────────────────

// Arcade-only: an attract-mode screen. Square pixel stars scrolling at three parallax
// speeds, a formation of invaders marching sideways in discrete steps, a cannon at the
// bottom taking a shot every couple of seconds, a red saucer crossing the top every 20s,
// CRT scanlines, and a blinking INSERT COIN. Everything snaps to whole steps on purpose.
struct ArcadeScreen: View {
    // Sprite bitmaps, two frames each. "X" = lit pixel.
    private static let squid = [
        ["...XX...", "..XXXX..", ".XXXXXX.", "XX.XX.XX", "XXXXXXXX", "..X..X..", ".X.XX.X.", "X.X..X.X"],
        ["...XX...", "..XXXX..", ".XXXXXX.", "XX.XX.XX", "XXXXXXXX", ".X.XX.X.", "X......X", ".X....X."]]
    private static let crab = [
        ["..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.", "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX..."],
        ["..X.....X..", "X..X...X..X", "X.XXXXXXX.X", "XXX.XXX.XXX", "XXXXXXXXXXX", ".XXXXXXXXX.", "..X.....X..", ".X.......X."]]
    private static let octopus = [
        ["....XXXX....", ".XXXXXXXXXX.", "XXXXXXXXXXXX", "XXX..XX..XXX", "XXXXXXXXXXXX", "...XX..XX...", "..XX.XX.XX..", "XX........XX"],
        ["....XXXX....", ".XXXXXXXXXX.", "XXXXXXXXXXXX", "XXX..XX..XXX", "XXXXXXXXXXXX", "..XXX..XXX..", ".XX..XX..XX.", "..XX....XX.."]]
    private static let cannon = [".....X.....", "....XXX....", "....XXX....", ".XXXXXXXXX.",
                                 "XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX"]
    private static let saucer = [".....XXXXXX.....", "...XXXXXXXXXX...", "..XXXXXXXXXXXX..",
                                 ".XX.XX.XX.XX.XX.", "XXXXXXXXXXXXXXXX", "..XXX..XX..XXX..", "...X........X..."]

    // Every lit pixel of a bitmap as one path, so a whole sprite is a single fill.
    private static func sprite(_ rows: [String], at origin: CGPoint, px: CGFloat, into p: inout Path) {
        for (r, line) in rows.enumerated() {
            for (c, ch) in line.enumerated() where ch == "X" {
                p.addRect(CGRect(x: origin.x + CGFloat(c) * px, y: origin.y + CGFloat(r) * px,
                                 width: px, height: px))
            }
        }
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let green = Color(hex: 0x39ff14), pink = Color(hex: 0xff3cac)
                let yellow = Color(hex: 0xffe600), red = Color(hex: 0xff2020)

                // Stars: three layers, nearer = bigger, brighter, faster. Snapped to 2pt.
                for i in 0..<80 {
                    let layer = i % 3
                    let speed = [14.0, 32.0, 70.0][layer]
                    let fx = Double((i * 263) % 1000) / 1000.0
                    let raw = (Double(i) * 97 + t * speed).truncatingRemainder(dividingBy: Double(h))
                    let y = floor(raw / 2) * 2
                    let s = CGFloat(1 + layer)
                    ctx.fill(Path(CGRect(x: floor(CGFloat(fx) * w), y: CGFloat(y), width: s, height: s)),
                             with: .color(Color.white.opacity(0.25 + 0.2 * Double(layer))))
                }

                // Invader formation: 5 across × 3 rows, one step every 0.5s, reversing at
                // the edges. The two animation frames swap on every step.
                let px: CGFloat = 3
                let cell: CGFloat = 12 * px, colGap: CGFloat = 14, rowGap: CGFloat = 14
                let formW = cell * 5 + colGap * 4
                let stepPx: CGFloat = 8
                let travelSteps = max(1, Int((w - formW - 32) / stepPx))
                let step = Int(floor(t / 0.5))
                let k = step % (travelSteps * 2)
                let offset = CGFloat(k < travelSteps ? k : travelSteps * 2 - k) * stepPx
                let frame = step % 2
                let formTop = h * 0.155
                let rows: [([[String]], Color)] = [(Self.squid, green), (Self.crab, pink), (Self.octopus, yellow)]
                for (r, (bitmaps, color)) in rows.enumerated() {
                    var p = Path()
                    let bm = bitmaps[frame]
                    let inset = (cell - CGFloat(bm[0].count) * px) / 2      // centre narrow sprites
                    for c in 0..<5 {
                        let origin = CGPoint(x: 16 + offset + CGFloat(c) * (cell + colGap) + inset,
                                             y: formTop + CGFloat(r) * (8 * px + rowGap))
                        Self.sprite(bm, at: origin, px: px, into: &p)
                    }
                    ctx.fill(p, with: .color(color.opacity(0.7)))
                }

                // Cannon: drifts along the bottom in 3pt steps.
                let cannonY = h * 0.85
                func cannonX(_ time: Double) -> CGFloat {
                    floor((w / 2 + CGFloat(sin(time * 0.35)) * w * 0.25) / 3) * 3
                }
                let shipX = cannonX(t)
                var ship = Path()
                Self.sprite(Self.cannon, at: CGPoint(x: shipX - 5.5 * px, y: cannonY), px: px, into: &ship)
                ctx.fill(ship, with: .color(green.opacity(0.8)))

                // Laser: fired every 2s from where the cannon was, climbing in 1/20s steps.
                let shotT = t.truncatingRemainder(dividingBy: 2)
                if shotT < 1.0 {
                    let fired = cannonX(t - shotT)
                    let climb = floor(shotT * 20) / 20
                    let top = formTop + 3 * (8 * px + rowGap)
                    let ly = cannonY - CGFloat(climb) * (cannonY - top)
                    ctx.fill(Path(CGRect(x: fired - 1.5, y: ly - 12, width: 3, height: 12)),
                             with: .color(Color.white.opacity(0.85)))
                } else if shotT < 1.15 {
                    // A little pixel burst where the shot lands.
                    let fired = cannonX(t - shotT)
                    let top = formTop + 3 * (8 * px + rowGap)
                    var burst = Path()
                    for (dx, dy) in [(0, 0), (-2, -2), (2, -2), (-2, 2), (2, 2), (0, -3), (0, 3), (-3, 0), (3, 0)] {
                        burst.addRect(CGRect(x: fired + CGFloat(dx) * px - 1.5, y: top + CGFloat(dy) * px - 1.5,
                                             width: px, height: px))
                    }
                    ctx.fill(burst, with: .color(Color.white.opacity(0.8)))
                }

                // Saucer: crosses the very top once every 20s, taking 6s.
                let ufoT = t.truncatingRemainder(dividingBy: 20)
                if ufoT < 6 {
                    let stepped = floor(ufoT * 20) / 20
                    let ux = -60 + CGFloat(stepped / 6) * (w + 120)
                    var ufo = Path()
                    Self.sprite(Self.saucer, at: CGPoint(x: ux, y: h * 0.075), px: px, into: &ufo)
                    ctx.fill(ufo, with: .color(red.opacity(0.85)))
                }

                // CRT scanlines.
                var y: CGFloat = 0
                var lines = Path()
                while y < h { lines.addRect(CGRect(x: 0, y: y, width: w, height: 1)); y += 3 }
                ctx.fill(lines, with: .color(Color.black.opacity(0.22)))

                // INSERT COIN, blinking on a hard 0.6s on/off.
                if Int(floor(t / 0.6)) % 2 == 0 {
                    ctx.draw(Text("INSERT COIN")
                                .font(.custom("PressStart2P-Regular", size: 10))
                                .foregroundColor(yellow.opacity(0.5)),
                             at: CGPoint(x: w / 2, y: h * 0.96))   // below the version line
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Dark-Academia-only: rain streaking down the glass. Many thin slanted streaks falling
// at varied speed, deterministic from the TimelineView clock (no Date()/RNG → resume-safe).
struct RainOverlay: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let slant: CGFloat = 0.2          // x-drift per unit fall → diagonal rain
                let span = Double(h + 200)
                for i in 0..<90 {
                    let fx = Double((i * 73) % 1000) / 1000.0
                    let speed = 680.0 + Double((i * 37) % 420)
                    let len: CGFloat = 22 + CGFloat((i * 13) % 26)
                    let x0 = CGFloat(fx) * (w + 140) - 70
                    let y = CGFloat((t * speed + Double(i) * 57).truncatingRemainder(dividingBy: span)) - 120
                    var path = Path()
                    path.move(to: CGPoint(x: x0, y: y))
                    path.addLine(to: CGPoint(x: x0 + slant * len, y: y + len))
                    ctx.stroke(path, with: .color(Theme.parchmentMid.opacity(0.22)), lineWidth: 1)
                }
            }
            .blendMode(.screen)
            .drawingGroup()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Blackletter-Noir-only: slow drifting banks of cold fog — a few big soft gray blobs
// sliding sideways. Deterministic from the clock; cheap additive screen blend.
struct FogOverlay: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                for k in 0..<6 {
                    let p = Double(k) * 1.6
                    let cx = w * CGFloat(0.5 + 0.6 * sin(t * 0.022 + p))
                    let cy = h * CGFloat(0.1 + 0.16 * Double(k))
                    let r: CGFloat = 440
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r * 0.5, width: r * 2, height: r)),
                             with: .radialGradient(
                                Gradient(colors: [Color(hex: 0x9a9eaa).opacity(0.15),
                                                  Color(hex: 0x6e7280).opacity(0.06),
                                                  Color(hex: 0x9a9eaa).opacity(0.0)]),
                                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r))
                }
            }
            .blendMode(.screen)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Blackletter-Noir-only: embers rising from the dark — faint glowing red motes that
// drift up and fade. Deterministic from the clock; cheap additive screen blend.
struct EmberOverlay: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let span = Double(h + 80)
                for i in 0..<22 {
                    let fx = Double((i * 89) % 1000) / 1000.0
                    let speed = 55.0 + Double((i * 31) % 70)        // slow upward px/s
                    let sway = sin(t * 0.8 + Double(i)) * 18
                    let x = CGFloat(fx) * w + CGFloat(sway)
                    let prog = (t * speed + Double(i) * 47).truncatingRemainder(dividingBy: span)
                    let y = h - CGFloat(prog)
                    let life = 1.0 - prog / span
                    let a = max(0.0, sin(life * .pi)) * 0.9          // fade in then out
                    let r: CGFloat = 1.5 + CGFloat(i % 3)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(
                                Gradient(colors: [Color(hex: 0xe0464d).opacity(a),
                                                  Color(hex: 0xe0464d).opacity(0)]),
                                center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 3))
                }
            }
            .blendMode(.screen)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
        // Arcade: a hard pixel edge, no blur.
        if Theme.mode == .arcade {
            content
                .overlay(Rectangle().stroke(Theme.border, lineWidth: 2))
        // Steady edged row everywhere except the electric themes (Tesla, Neon).
        } else if Theme.mode != .tesla && Theme.mode != .neon {
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
