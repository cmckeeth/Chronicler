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

            // Garden: a few drifting petals/leaves on the backdrop (no electricity).
            if themeStore.mode == .garden {
                PetalDrift()
                VineGrowOverlay()   // vines grow up, flowers bloom at the tips (garden only)
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
    // electricity), 🌿 Garden (verdant green/floral, no electricity). Persisted by
    // ThemeStore; the root re-renders via `.id(mode)`.
    private var themePicker: some View {
        Menu {
            Picker("Theme", selection: $themeStore.mode) {
                Text("⚡ Tesla").tag(ThemeMode.tesla)
                Text("⚙ Steampunk").tag(ThemeMode.steampunk)
                Text("🌿 Garden").tag(ThemeMode.garden)
            }
        } label: {
            HStack(spacing: 5) {
                Text(themeIcon)
                Text(themeLabel)
            }
            .font(Theme.body(11))
            .foregroundColor(Theme.parchmentMid)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.borderBrass.opacity(0.6), lineWidth: 1))
        }
    }

    private var themeIcon: String {
        switch themeStore.mode {
        case .tesla: return "⚡"
        case .steampunk: return "⚙"
        case .garden: return "🌿"
        }
    }
    private var themeLabel: String {
        switch themeStore.mode {
        case .tesla: return "Tesla"
        case .steampunk: return "Steampunk"
        case .garden: return "Garden"
        }
    }
}

// Garden-only: a few petals/leaves drifting gently down the backdrop. Deterministic
// from time (no RNG, resume-safe). One TimelineView positioning a handful of emoji —
// cheap and clearly NOT electricity.
private struct PetalDrift: View {
    private let glyphs = ["🌸", "🍃", "🌿", "🌷", "🍀", "🌸", "🍃"]
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(glyphs.indices, id: \.self) { i in
                        let p = Double(i) * 1.7
                        let fall = (t * (0.05 + 0.02 * Double(i % 3)) + Double(i) * 0.13)
                            .truncatingRemainder(dividingBy: 1.0)
                        let x = geo.size.width * (0.08 + 0.84 * (0.5 + 0.5 * sin(t * 0.12 + p)))
                        let y = geo.size.height * fall
                        Text(glyphs[i])
                            .font(.system(size: 34 + CGFloat(i % 3) * 8))
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                            .rotationEffect(.degrees(sin(t * 0.4 + p) * 30))
                            .position(x: x, y: y)
                    }
                }
            }
        }
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
        let flower: String
        let leaves: [CGFloat]   // positions along the stem (0 = base, 1 = tip)
    }

    // bottom-left, bottom-center, bottom-right — varied heights.
    private let vines: [Vine] = [
        Vine(xFraction: 0.16, heightFraction: 0.34, width: 80, sway:  1.0,
             flower: "🌸", leaves: [0.32, 0.62]),
        Vine(xFraction: 0.84, heightFraction: 0.42, width: 90, sway: -1.0,
             flower: "🌷", leaves: [0.28, 0.55, 0.78]),
        Vine(xFraction: 0.50, heightFraction: 0.28, width: 70, sway:  0.5,
             flower: "🌼", leaves: [0.40, 0.70]),
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

            // leaves staggered along the grow.
            ForEach(v.leaves.indices, id: \.self) { j in
                let f = v.leaves[j]
                let lx = baseX + (0.5 - 0.5) * stemW + leafOffsetX(v.sway, f) * stemW
                let ly = baseY - stemH * f
                Text("🍃")
                    .font(.system(size: 24))
                    .scaleEffect(grow ? 1 : 0)
                    .opacity(grow ? 1 : 0)
                    .rotationEffect(.degrees(j.isMultiple(of: 2) ? -25 : 25))
                    .position(x: lx, y: ly)
                    .animation(.easeOut(duration: 0.5).delay(growDuration * Double(f) * 0.9),
                               value: grow)
            }

            // flower at the tip — blooms after the stem finishes.
            Text(v.flower)
                .font(.system(size: 60))
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
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
