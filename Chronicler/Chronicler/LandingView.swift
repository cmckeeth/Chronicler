import SwiftUI

enum Route: Hashable {
    case archive
    case book(Book)
    case collection(Collection)
    case offline
}

struct LandingView: View {
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var themeStore: ThemeStore

    // Starts optimistic so the common (online) case doesn't flash the offline panel
    // during the first reachability poll; UpdateBanner corrects it within a second.
    @State private var connected = true

    var body: some View {
        ZStack {
            ThemedBackground(intensity: 2.2)   // homepage should be buzzin

            // Steampunk: an industrial factory skyline pinned to the bottom, behind the
            // content. The 5 smokestacks line up with SteamOverlay's rising plumes.
            if themeStore.mode == .steampunk {
                FactorySkyline()
            }

            // Garden: a row of real painted-rose images standing along the bottom edge
            // (rising up like a garden bed), plus a couple larger ones set back near the
            // side margins. ~50% opacity, grow-in staggered on appear, gentle sway.
            // Non-interactive so it never blocks the content above.
            if themeStore.mode == .garden {
                GardenRoseBackground()
            }

            // Steampunk: large, slowly-rotating brass cogs in the corners (subtle
            // background machinery), plus lush rising steam over the brass void.
            if themeStore.mode == .steampunk {
                CornerCogs()
                SteamOverlay()
            }

            VStack(spacing: 0) {
                Spacer()

                // One action, and it follows the connection: the Archive needs the
                // server, so when it can't be reached the panel becomes the way into
                // the downloads on this device instead of a button that would fail.
                NavigationLink(value: connected ? Route.archive : Route.offline) {
                    VStack(spacing: 4) {
                        if themeStore.mode == .ransom {
                            RansomWordmark(text: "Chronicler", size: 34)
                        } else {
                            Text("Chronicler")
                                .font(Theme.display(48))
                                .foregroundStyle(Theme.brassGradient)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .glowVerdigris()
                        }
                        Text(connected ? "Your Audiobook Library" : "Server unreachable")
                            .font(Theme.serif(15))
                            .foregroundColor(connected ? Theme.parchmentDim : Theme.rust)
                        Text(connected ? "Enter the Archive" : "📥 Listen to Downloads")
                            .font(Theme.serif(16)).foregroundColor(Theme.brassPale)
                            .padding(.top, 16)
                            .glowVerdigris()
                    }
                    .padding(.horizontal, 34)
                    .padding(.vertical, 30)
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
                UpdateBanner(api: auth.api, onStatus: { connected = $0 }).padding(.bottom, 12)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { StartupSound.shared.play() }
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
            Text("📖 Dark Academia").tag(ThemeMode.academia)
            Text("🦇 Blackletter Noir").tag(ThemeMode.noir)
            Text("🤠 Wild West").tag(ThemeMode.west)
            Text("🌴 Neon Sunset").tag(ThemeMode.neon)
            Text("🌋 Molten Forge").tag(ThemeMode.forge)
            Text("✂️ Ransom Note").tag(ThemeMode.ransom)
        }
        .pickerStyle(.menu)
        .font(Theme.body(11))
        .tint(Theme.parchmentMid)
        .padding(.horizontal, 6).padding(.vertical, 1)
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(Theme.borderBrass.opacity(0.6), lineWidth: 1))
    }
}

// Garden-only BACKGROUND layer: a bed of real painted-rose images (rose head + leafy
// stem, transparent PNG) standing along the bottom edge of the screen — a row of stems
// rising up — plus a couple larger roses set back near the side margins. Drawn at ~50%
// opacity behind the Landing content (so they read softly through the translucent garden
// panels). Each rose grows/rises IN on appear (staggered) and sways gently, with the
// transform anchored at the bottom so the stems stay rooted. Non-interactive.
private struct GardenRoseBackground: View {
    private struct Rose {
        let widthFrac: CGFloat   // rose width as a fraction of screen width
        let xFrac: CGFloat       // horizontal center as a fraction of screen width
        let yOffset: CGFloat     // vertical lift of the bottom from the screen bottom (pt)
        let phase: Double        // sway phase offset
        let swayAmp: Double      // sway amplitude (degrees)
        let opacity: Double
        let delay: Double        // grow-in stagger (seconds)
    }
    // rose.png is 382x488 (h/w ≈ 1.277). Front row: a rising row of stems across the
    // bottom; back: two larger roses set near the side margins.
    private let aspect: CGFloat = 488.0 / 382.0
    private let roses: [Rose] = [
        // two larger ones set back near the side margins
        Rose(widthFrac: 0.46, xFrac: 0.08, yOffset: 10, phase: 0.0, swayAmp: 2.5, opacity: 0.42, delay: 0.05),
        Rose(widthFrac: 0.44, xFrac: 0.93, yOffset: 18, phase: 1.7, swayAmp: 2.5, opacity: 0.42, delay: 0.15),
        // front row along the bottom — a row rising up, varied heights
        Rose(widthFrac: 0.26, xFrac: 0.20, yOffset: 0,  phase: 0.6, swayAmp: 3.5, opacity: 0.55, delay: 0.30),
        Rose(widthFrac: 0.30, xFrac: 0.40, yOffset: -8, phase: 2.3, swayAmp: 3.5, opacity: 0.55, delay: 0.45),
        Rose(widthFrac: 0.27, xFrac: 0.60, yOffset: 4,  phase: 1.1, swayAmp: 3.5, opacity: 0.55, delay: 0.60),
        Rose(widthFrac: 0.29, xFrac: 0.80, yOffset: -4, phase: 3.0, swayAmp: 3.5, opacity: 0.55, delay: 0.75),
    ]

    // 0 → 1 on appear: each rose scales up from a small size at its bottom-anchored
    // base, so the roses pop/grow in from the ground.
    @State private var grow = 0.0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(roses.indices, id: \.self) { i in
                        let r = roses[i]
                        let w = geo.size.width * r.widthFrac
                        let h = w * aspect
                        let sway = sin(t * 0.5 + r.phase) * r.swayAmp
                        Image("rose")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: w, height: h)
                            .opacity(r.opacity * grow)
                            // scale-in: each rose grows from a small size at the bottom,
                            // so it pops/grows up out of the ground.
                            .scaleEffect(0.25 + 0.75 * grow, anchor: .bottom)
                            // sway anchored at the bottom so stems stay rooted.
                            .rotationEffect(.degrees(sway), anchor: .bottom)
                            // position the BOTTOM of the rose at the screen bottom (minus lift).
                            .position(x: geo.size.width * r.xFrac,
                                      y: geo.size.height - r.yOffset - h / 2)
                            .animation(.easeOut(duration: 2.2).delay(r.delay), value: grow)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { grow = 1.0 }
    }
}


// Ransom-Note-only wordmark: every letter is cut from a different magazine, so each one
// gets its own face, rotation, size jitter and paper swatch. Deterministic from the
// character index (no RNG) so it looks hand-made but never reflows between renders.
struct RansomWordmark: View {
    let text: String
    var size: CGFloat

    // Faces already bundled for the other themes — mixing them IS the effect.
    private let faces = ["SpecialElite-Regular", "Rye-Regular", "ZillaSlab-SemiBold",
                         "AlfaSlabOne-Regular", "Cinzel-Regular", "Monoton-Regular"]
    // Newsprint / marker swatches behind each letter.
    private let swatches: [UInt] = [0xf4f1e8, 0x141414, 0xff2d55, 0xe8e4d9, 0x00b3a4, 0xd6d0bd]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                let face = faces[i % faces.count]
                let swatch = Color(hex: swatches[(i * 5 + 2) % swatches.count])
                // Dark swatches need light ink and vice versa.
                let dark = [0x141414, 0xff2d55, 0x00b3a4].contains(Int(swatches[(i * 5 + 2) % swatches.count]))
                let tilt = Double((i % 5) - 2) * 3.4
                let jitter = 1 + CGFloat((i % 3)) * 0.09
                Text(String(ch))
                    .font(.custom(face, size: size * jitter * Theme.fontScale))
                    .foregroundColor(dark ? Color(hex: 0xf4f1e8) : Color(hex: 0x141414))
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(swatch)
                    .overlay(Rectangle().stroke(Color.black.opacity(0.35), lineWidth: 0.8))
                    .rotationEffect(.degrees(tilt))
                    .offset(y: CGFloat((i % 4) - 2) * 1.6)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 1.5, y: 1.5)
            }
        }
        .padding(.vertical, 6)
    }
}

// Status bar (connection dot + app version), ported from the Android UpdateBanner.
// iOS can't self-install APKs, so we never show the "tap to install" prompt — just
// the dot + version + Connected / Server unreachable. Shared by landing + archive.
struct UpdateBanner: View {
    let api: APIClient
    // Lets the hosting screen react to the connection state (e.g. surface Local Downloads).
    var onStatus: ((Bool) -> Void)? = nil
    // Archive uses the compact form so the status line costs as little height as
    // possible — the covers want that space.
    var compact: Bool = false
    @State private var connected = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        HStack(spacing: compact ? 5 : 8) {
            Text("●").font(.system(size: compact ? 7 : 10))
                .foregroundColor(connected ? Theme.verdigris : Theme.rust)
            Text("v\(version)")
                .font(Theme.body(compact ? 10 : 12)).foregroundColor(Theme.parchmentDim)
            Text(connected ? "Connected" : "Server unreachable")
                .font(Theme.body(compact ? 10 : 12)).foregroundColor(Theme.parchmentDim)
        }
        .task {
            while !Task.isCancelled {
                connected = (await api.getLatestVersion()) != nil
                onStatus?(connected)
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
}
