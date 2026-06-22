import SwiftUI

enum Route: Hashable {
    case archive
    case book(Book)
}

struct LandingView: View {
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var themeStore: ThemeStore

    var body: some View {
        ZStack {
            ThemedBackground(intensity: 2.2)   // homepage should be buzzin

            // Garden: large hand-built VECTOR flowers as a soft (~50%) background
            // wallpaper, plus the growing vine stems (now tipped with vector blooms).
            // No emoji — and non-interactive so it never blocks the content above.
            if themeStore.mode == .garden {
                GardenFlowerBackground()
                VineGrowOverlay()   // vines grow up, vector flowers bloom at the tips
            }

            // Gear corners (⚙ in tl/tr/bl/br)
            VStack {
                HStack { gear; Spacer(); gear }
                Spacer()
                HStack { gear; Spacer(); gear }
            }
            .padding(20)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Text("Chronicler")
                    .font(Theme.display(56))
                    .foregroundStyle(Theme.brassGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .glowVerdigris()
                Text("Your Audiobook Library")
                    .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim)
                    .padding(.top, 4)
                Text("⚙ ───────── ⚙")
                    .font(Theme.serif(14)).foregroundColor(Theme.borderBrass)
                    .padding(.top, 10)

                Spacer().frame(height: 40)

                NavigationLink(value: Route.archive) {
                    VStack(spacing: 6) {
                        Image("logo").resizable().scaledToFit().frame(width: 190, height: 190)
                            .glowVerdigris()
                        Text("Enter the Archive")
                            .font(Theme.serif(20)).foregroundColor(Theme.brassPale)
                            .glowVerdigris()
                    }
                    .padding(28)
                    .electricPanel(bg: Theme.surface, corner: 6, alpha: 0.8, glowRadius: 20)
                }

                Spacer()
                Spacer()
            }
            .padding()

            VStack {
                HStack(spacing: 12) {
                    themePicker
                    Spacer()
                    Button("Sign Out") { auth.clear() }
                        .font(Theme.body(11)).foregroundColor(Theme.parchmentDim).opacity(0.5)
                }
                Spacer()
                UpdateBanner(api: auth.api).padding(.bottom, 12)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { StartupSound.shared.play() }
    }

    private var gear: some View {
        Text("⚙").font(.system(size: 26)).foregroundColor(Theme.border).opacity(0.6)
    }

    // Runtime theme switcher: ⚡ Tesla (electric blue), ⚙ Steampunk (brass, no
    // electricity), 🌿 Garden (verdant green/floral, no electricity). A standard
    // SwiftUI dropdown (`.pickerStyle(.menu)`): a label + chevron that opens the list
    // of the three options. Persisted by ThemeStore; the root re-renders via `.id(mode)`.
    private var themePicker: some View {
        Picker("Theme", selection: $themeStore.mode) {
            Text("⚡ Tesla").tag(ThemeMode.tesla)
            Text("⚙ Steampunk").tag(ThemeMode.steampunk)
            Text("🌿 Garden").tag(ThemeMode.garden)
        }
        .pickerStyle(.menu)
        .font(Theme.body(11))
        .tint(Theme.parchmentMid)
        .padding(.horizontal, 6).padding(.vertical, 1)
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(Theme.borderBrass.opacity(0.6), lineWidth: 1))
    }
}

// A light→saturated hue pair for a vector flower's petals (ported from the web app's
// FLOWER_HUES). The petal radial gradient runs light→dark; rose is the default.
enum FlowerHue: CaseIterable {
    case rose, gold, lilac, white, coral
    var light: Color {
        switch self {
        case .rose:  return Color(hex: 0xffd6e6)
        case .gold:  return Color(hex: 0xfff0bf)
        case .lilac: return Color(hex: 0xecd6ff)
        case .white: return Color(hex: 0xffffff)
        case .coral: return Color(hex: 0xffd9bf)
        }
    }
    var dark: Color {
        switch self {
        case .rose:  return Color(hex: 0xff4f8e)
        case .gold:  return Color(hex: 0xffa61f)
        case .lilac: return Color(hex: 0x9b54ff)
        case .white: return Color(hex: 0xcfe0e6)
        case .coral: return Color(hex: 0xff6a3c)
        }
    }
}

// A hand-built VECTOR bloom (no emoji), ported from the web app's <Flower> SVG: a
// golden gradient center ringed by tall gradient-shaded petals, with a second smaller
// offset ring for fullness. Drawn in a 100x100 unit space and scaled to `.frame`.
// `petals` controls density (web default 13).
struct Flower: View {
    var hue: FlowerHue = .rose
    var petals: Int = 13

    // Petal radial gradient: light core → saturated edge (matches web cx 50% cy 84%).
    private var petalFill: RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: hue.light, location: 0.0),
                .init(color: hue.dark,  location: 0.62),
                .init(color: hue.dark.opacity(0.85), location: 1.0),
            ]),
            center: UnitPoint(x: 0.5, y: 0.84), startRadius: 0, endRadius: 0.78 * 100)
    }
    // Golden textured center (#ffe784 → #f0a800 → #9c6400).
    private var centerFill: RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: 0xffe784), location: 0.0),
                .init(color: Color(hex: 0xf0a800), location: 0.55),
                .init(color: Color(hex: 0x9c6400), location: 1.0),
            ]),
            center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 0.62 * 26)
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 100   // unit (100) → points
            ZStack {
                ring(count: petals, ry: 26, cy: 26, rot: 0, scale: s)
                ring(count: petals, ry: 19, cy: 33, rot: 360 / Double(petals) / 2, scale: s)
                // Golden center.
                Circle().fill(centerFill)
                    .frame(width: 26 * s, height: 26 * s)
                    .position(x: 50 * s, y: 50 * s)
                // Stamen dots.
                ForEach(0..<10, id: \.self) { k in
                    Circle().fill(Color(hex: 0x7a4e00).opacity(0.5))
                        .frame(width: 3 * s, height: 3 * s)
                        .position(x: (50 + 7 * cos(Double(k) * 2.4)) * s,
                                  y: (50 + 7 * sin(Double(k) * 2.4)) * s)
                }
            }
            .frame(width: 100 * s, height: 100 * s)
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.45), radius: 4, y: 4)   // matches web drop-shadow
    }

    // One ring of `count` tall petals (Ellipse, rx ≈ 0.38*ry) rotated around the center.
    @ViewBuilder
    private func ring(count: Int, ry: Double, cy: Double, rot: Double, scale s: CGFloat) -> some View {
        ForEach(0..<count, id: \.self) { k in
            Ellipse().fill(petalFill).opacity(0.95)
                .frame(width: ry * 0.38 * 2 * s, height: ry * 2 * s)
                .position(x: 50 * s, y: cy * s)   // anchored above center, then rotated about center
                .rotationEffect(.degrees(rot + (360 / Double(count)) * Double(k)),
                                anchor: .center)
        }
    }
}

// Garden-only BACKGROUND layer: several large vector Flowers at varied hue/size/
// position, gently swaying, drawn at ~50% opacity behind the Landing content (so they
// read softly through the translucent garden panels). Non-interactive. Positions
// mirror the web .bf-1..5 wallpaper.
private struct GardenFlowerBackground: View {
    private struct Bloom {
        let hue: FlowerHue
        let petals: Int
        let widthFrac: CGFloat   // size as fraction of screen width
        let x: CGFloat, y: CGFloat   // center as fraction of screen (may go off-edge)
        let phase: Double        // sway offset
        let reverse: Bool
    }
    // rose / gold / lilac / coral / white — large, edges bleeding off-screen.
    private let blooms: [Bloom] = [
        Bloom(hue: .rose,  petals: 13, widthFrac: 0.62, x: -0.02, y: 0.02, phase: 0.0, reverse: false),
        Bloom(hue: .gold,  petals: 15, widthFrac: 0.44, x: 1.02,  y: 0.28, phase: 1.1, reverse: true),
        Bloom(hue: .lilac, petals: 13, widthFrac: 0.50, x: 0.40,  y: 1.02, phase: 2.0, reverse: false),
        Bloom(hue: .coral, petals: 13, widthFrac: 0.36, x: -0.04, y: 0.52, phase: 0.7, reverse: true),
        Bloom(hue: .white, petals: 14, widthFrac: 0.38, x: 0.42,  y: 0.34, phase: 1.6, reverse: false),
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(blooms.indices, id: \.self) { i in
                        let b = blooms[i]
                        let dir: Double = b.reverse ? -1 : 1
                        let sway = sin(t * 0.18 + b.phase) * 5 * dir   // gentle ±5° lean
                        let w = geo.size.width * b.widthFrac
                        Flower(hue: b.hue, petals: b.petals)
                            .frame(width: w, height: w)
                            .rotationEffect(.degrees(sway))
                            .position(x: geo.size.width * b.x, y: geo.size.height * b.y)
                    }
                }
            }
        }
        .opacity(0.5)            // soft wallpaper — ambiance, not foreground
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Garden-only: a curvy vine stem rising from the bottom edge. The path is built in a
// unit rect (0..1, y inverted so it climbs upward) and scaled to the given size, so it
// can be `.trim`-animated to "draw" itself growing. `sway` shifts the horizontal
// control points to give each vine its own gentle lean.
private struct VineStem: Shape {
    var sway: CGFloat   // -1..1, leans the curve left/right

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        // y: 1 = bottom of rect, 0 = top. Climb from bottom-center up with two S-curves.
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + (1 - y) * h)
        }
        var p = Path()
        p.move(to: pt(0.5, 0.0))
        p.addCurve(to: pt(0.5 + 0.18 * sway, 0.5),
                   control1: pt(0.5 - 0.22 * sway, 0.18),
                   control2: pt(0.5 + 0.30 * sway, 0.34))
        p.addCurve(to: pt(0.5 - 0.04 * sway, 1.0),
                   control1: pt(0.5 + 0.10 * sway, 0.66),
                   control2: pt(0.5 - 0.26 * sway, 0.84))
        return p
    }
}

// Garden-only: a few vine stems grow upward from the bottom edge on appear. Each stem
// draws itself in via `.trim` over ~3s (easeOut), small leaves (🍃) fade/scale in along
// the way at staggered delays, and once the stem finishes a flower blooms at its tip
// with a slow, gently-overshooting spring. Grows once and holds. Non-interactive.
private struct VineGrowOverlay: View {
    private struct Vine {
        let xFraction: CGFloat   // horizontal anchor of the stem base (0..1)
        let heightFraction: CGFloat   // stem height as fraction of screen height
        let width: CGFloat   // stem bounding-box width in points
        let sway: CGFloat   // lean for VineStem
        let hue: FlowerHue  // hue of the vector flower at the tip
        let leaves: [CGFloat]   // positions along the stem (0 = base, 1 = tip)
    }

    // bottom-left, bottom-center, bottom-right — varied heights.
    private let vines: [Vine] = [
        Vine(xFraction: 0.16, heightFraction: 0.34, width: 80, sway:  1.0,
             hue: .rose, leaves: [0.32, 0.62]),
        Vine(xFraction: 0.84, heightFraction: 0.42, width: 90, sway: -1.0,
             hue: .white, leaves: [0.28, 0.55, 0.78]),
        Vine(xFraction: 0.50, heightFraction: 0.28, width: 70, sway:  0.5,
             hue: .gold, leaves: [0.40, 0.70]),
    ]

    private let growDuration: Double = 3.0

    @State private var grow = false
    @State private var bloomed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(vines.indices, id: \.self) { i in
                    vineView(vines[i], in: geo.size)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: growDuration)) { grow = true }
            // bloom only after the stem finishes drawing.
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)
                .delay(growDuration)) { bloomed = true }
        }
    }

    @ViewBuilder
    private func vineView(_ v: Vine, in size: CGSize) -> some View {
        let stemW = v.width
        let stemH = size.height * v.heightFraction
        let baseX = size.width * v.xFraction
        let baseY = size.height                // bottom edge
        let tipX = baseX + (0.5 - 0.04 * v.sway - 0.5) * stemW   // matches VineStem tip x
        let tipY = baseY - stemH

        ZStack {
            VineStem(sway: v.sway)
                .trim(from: 0, to: grow ? 1 : 0)
                .stroke(Color(red: 0x6F/255, green: 0xAE/255, blue: 0x5F/255),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: stemW, height: stemH)
                .position(x: baseX, y: baseY - stemH / 2)

            // leaves staggered along the grow — small green vector ellipses (no emoji).
            ForEach(v.leaves.indices, id: \.self) { j in
                let f = v.leaves[j]
                let lx = baseX + leafOffsetX(v.sway, f) * stemW
                let ly = baseY - stemH * f
                Ellipse()
                    .fill(Color(hex: 0x5a9e46))
                    .frame(width: 26, height: 11)
                    .scaleEffect(grow ? 1 : 0)
                    .opacity(grow ? 1 : 0)
                    .rotationEffect(.degrees(j.isMultiple(of: 2) ? -30 : 30))
                    .position(x: lx, y: ly)
                    .animation(.easeOut(duration: 0.5).delay(growDuration * Double(f) * 0.9),
                               value: grow)
            }

            // VECTOR flower at the tip — blooms after the stem finishes drawing.
            Flower(hue: v.hue)
                .frame(width: 84, height: 84)
                .scaleEffect(bloomed ? 1 : 0)
                .position(x: tipX, y: tipY)
        }
    }

    // approximate horizontal offset of the stem at fraction f (rough lean toward sway).
    private func leafOffsetX(_ sway: CGFloat, _ f: CGFloat) -> CGFloat {
        0.10 * sway * sin(f * .pi)
    }
}

// Status bar (connection dot + app version), ported from the Android UpdateBanner.
// iOS can't self-install APKs, so we never show the "tap to install" prompt — just
// the dot + version + Connected / Server unreachable. Shared by landing + archive.
struct UpdateBanner: View {
    let api: APIClient
    @State private var connected = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("●").font(.system(size: 10))
                .foregroundColor(connected ? Theme.verdigris : Theme.rust)
            Text("v\(version)").font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
            Text(connected ? "Connected" : "Server unreachable")
                .font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
        }
        .task {
            while !Task.isCancelled {
                connected = (await api.getLatestVersion()) != nil
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
}
