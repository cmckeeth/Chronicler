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
                BloomOverlay()   // flowers bloom open on appear (garden only)
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
                            .font(.system(size: 22 + CGFloat(i % 3) * 6))
                            .opacity(0.5)
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

// Garden-only: flowers bloom open on appear. Each glyph is positioned around the
// edges/corners (so it doesn't cover the main controls) and springs from a closed
// bud (scale 0) past a slight overshoot to full size, with a small rotation and a
// staggered start delay. Blooms once and holds. Non-interactive (no tap blocking).
private struct BloomOverlay: View {
    // glyph, relative position (0..1), size, target rotation degrees, stagger delay
    private struct Flower {
        let glyph: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let rotation: Double
        let delay: Double
    }
    private let flowers: [Flower] = [
        Flower(glyph: "🌸", x: 0.10, y: 0.12, size: 40, rotation: -12, delay: 0.10),
        Flower(glyph: "🌷", x: 0.90, y: 0.14, size: 38, rotation:  10, delay: 0.30),
        Flower(glyph: "🌼", x: 0.08, y: 0.86, size: 36, rotation:  14, delay: 0.50),
        Flower(glyph: "🌺", x: 0.92, y: 0.84, size: 42, rotation: -10, delay: 0.70),
        Flower(glyph: "🌻", x: 0.50, y: 0.06, size: 34, rotation:   8, delay: 0.90),
    ]
    @State private var bloomed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(flowers.indices, id: \.self) { i in
                    let f = flowers[i]
                    Text(f.glyph)
                        .font(.system(size: f.size))
                        .scaleEffect(bloomed ? 1.0 : 0.0)
                        .rotationEffect(.degrees(bloomed ? f.rotation : -90))
                        .position(x: geo.size.width * f.x, y: geo.size.height * f.y)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.6).delay(f.delay),
                            value: bloomed)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { bloomed = true }
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
