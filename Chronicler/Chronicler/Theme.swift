import SwiftUI
import Combine

// Eleven runtime themes. Tesla = electric-blue look; Steampunk = Victorian brass/gold
// with NO electricity; Garden = verdant greens + floral pink, soft/organic, NO electricity.
// Academia = espresso/forest-green/cream/brass, rainy-university serif, NO electricity.
// Noir = black/ox-blood/cold-gray/tarnished-silver, gothic, sharp shadows, NO electricity.
// West = sun-bleached desert dusk: leather browns, sheriff-star gold, turquoise accent,
// wood-type lettering, NO electricity.
// Neon = 1984 vaporwave: indigo void, hot-magenta chrome, cyan accent, scrolling
// perspective grid + banded sun. The only other theme besides Tesla that pulses.
// Forge = obsidian and lava: black rock with glowing fissures, molten-orange metal,
// white-hot accent, churning lava and spitting sparks.
// Ransom = photocopied punk zine: the one LIGHT theme — newsprint paper, black ink,
// hot-pink accent, cut-out ransom-note wordmark, everything slightly askew.
// Abyss = the deep sea: teal bioluminescence on black water, violet accent, drifting
// jellyfish, marine snow, and something very large that occasionally looks back.
// Arcade = 1980s cabinet: black screen, yellow/pink/green phosphor, pixel fonts, a
// marching invader formation. Hard pixel shadows, no blur anywhere.
// Mirrors the web frontend's theme switcher.
enum ThemeMode: String { case tesla, steampunk, garden, academia, noir, west, neon, forge, ransom,
                             abyss, arcade }

// Themed palette. Colors are computed properties that switch on `Theme.mode`.
// TESLA values are the original hardcoded set; STEAMPUNK is a warmer brass set
// with a GREEN accent (verdigris) instead of the electric blue.
enum Theme {
    // Live theme. Mutated by ThemeStore; views re-render via `.id(themeStore.mode)`.
    static var mode: ThemeMode = .tesla

    private static var s: Bool { mode == .steampunk }
    private static var g: Bool { mode == .garden }

    // Eleven-way palette pick, in declaration order. Long, but it keeps the table below
    // readable as a matrix: one row per token, one column per theme.
    private static func pick(_ tesla: UInt, _ steampunk: UInt, _ garden: UInt,
                             _ academia: UInt, _ noir: UInt, _ west: UInt,
                             _ neon: UInt, _ forge: UInt, _ ransom: UInt,
                             _ abyss: UInt, _ arcade: UInt) -> Color {
        switch mode {
        case .tesla:     return Color(hex: tesla)
        case .steampunk: return Color(hex: steampunk)
        case .garden:    return Color(hex: garden)
        case .academia:  return Color(hex: academia)
        case .noir:      return Color(hex: noir)
        case .west:      return Color(hex: west)
        case .neon:      return Color(hex: neon)
        case .forge:     return Color(hex: forge)
        case .ransom:    return Color(hex: ransom)
        case .abyss:     return Color(hex: abyss)
        case .arcade:    return Color(hex: arcade)
        }
    }

    // Tesla = cold electric-blue glass. Steampunk = warm brass/leather. Garden = verdant
    // greens (metal→foliage, accent→floral pink). Academia = espresso wood, brass metal,
    // cream text, forest-green accent. Noir = near-black, tarnished-silver metal, cold-gray
    // text, ox-blood accent.
    //                            ( tesla   ,  steampunk,  garden  ,  academia,  noir    ,  west    ,  neon    ,  forge   ,  ransom  ,  abyss   ,  arcade  )
    static var bg: Color          { pick(0x05080f, 0x160d03, 0x0b1410, 0x161009, 0x040406, 0x150e08, 0x150726, 0x0b0705, 0xe8e4d9, 0x020a12, 0x000000) }
    static var bg2: Color         { pick(0x090e1a, 0x1e1206, 0x0f1c14, 0x1d150c, 0x08080b, 0x1f150c, 0x1e0a35, 0x140a06, 0xf1ede2, 0x041420, 0x0a0a14) }
    static var leather: Color     { pick(0x0b1424, 0x281809, 0x12241a, 0x2a1d10, 0x0c0c10, 0x2b1d10, 0x2a0f45, 0x1c100a, 0xdcd7c8, 0x06202e, 0x10101e) }
    static var surface: Color     { pick(0x0f1a2e, 0x32200c, 0x16301f, 0x2f2211, 0x101015, 0x362514, 0x33124f, 0x241309, 0xf4f1e8, 0x08283a, 0x14142a) }
    static var surface2: Color    { pick(0x142440, 0x3e280e, 0x1d3d28, 0x3a2b16, 0x17171e, 0x442f1a, 0x431a63, 0x30190c, 0xe4dfd0, 0x0c3448, 0x1c1c3a) }
    static var surface3: Color    { pick(0x1b3052, 0x4a3012, 0x245031, 0x46351c, 0x212129, 0x543a20, 0x552279, 0x3d2110, 0xd6d0bd, 0x114258, 0x26264c) }
    static var border: Color      { pick(0x21405f, 0x6b4420, 0x2f5c3c, 0x5a4527, 0x2e2e38, 0x6d4a28, 0x7b34a8, 0x5c3315, 0x8c8677, 0x1a5a6e, 0x3a3a7a) }
    static var borderBrass: Color { pick(0x3f86b8, 0xc08828, 0x6fae5f, 0x9a7b3e, 0x7e818c, 0xc08a45, 0xff4fd8, 0xff8a1f, 0x141414, 0x2fd9b4, 0xffe600) }  // trim
    // The "brass"/metal: Tesla electric-blue chrome, Steampunk gold, Garden foliage green,
    // Academia antique brass, Noir bone/tarnished silver (buttons + wordmark).
    static var brass: Color       { pick(0x2bc4ff, 0xe09808, 0x8bd450, 0xc39a4e, 0xc4c8d2, 0xd9a441, 0xff4fd8, 0xff8a1f, 0x141414, 0x3dffc8, 0xffe600) }
    static var brassLight: Color  { pick(0x7fe0ff, 0xffc838, 0xb6f07a, 0xe3c275, 0xe2e5ec, 0xf0c46f, 0xff8ce6, 0xffab4d, 0x2e2e2e, 0x8affe0, 0xfff27a) }
    static var brassPale: Color   { pick(0xd6f4ff, 0xffe878, 0xe2ffc0, 0xf4e6b8, 0xf2f4f8, 0xffe3ab, 0xffc4f2, 0xffd7a1, 0x4a4a4a, 0xd4fff2, 0xfffbc2) }
    static var copper: Color      { pick(0x1f9fd8, 0xc86818, 0xe88fa8, 0x7d9b6a, 0x6e0d13, 0xb4552b, 0x22e0ff, 0xe02b0a, 0x00b3a4, 0xb86bff, 0xff3cac) }
    static var copperLight: Color { pick(0x5ac8ff, 0xe88838, 0xffb0c8, 0xa3c089, 0x9c1820, 0xd97a45, 0x7defff, 0xff5a2a, 0x2ad4c6, 0xd4a3ff, 0xff7cc8) }
    static var rust: Color        { pick(0xff5470, 0xb82c0c, 0xd4564a, 0xa23b22, 0xc41019, 0xc0392b, 0xff2d7a, 0xe02b0a, 0xd11a3a, 0xff4d8d, 0xff2020) }
    // Accent / "electric" color. Tesla = electric blue (drives glow + panel). Steampunk =
    // verdigris green. Garden = floral PINK. Academia = forest green. Noir = ox-blood red.
    static var verdigris: Color   { pick(0x2bc4ff, 0x8fd44a, 0xff8fb8, 0x4f8a52, 0xa8121b, 0x3fb0a3, 0x22e0ff, 0xffd23f, 0xff2d55, 0xb86bff, 0x39ff14) }
    static var parchment: Color   { pick(0xe6f3ff, 0xf6ecd0, 0xf0f7e8, 0xf2e7cf, 0xd9dbe2, 0xf3e3c3, 0xf2e9ff, 0xffe8d6, 0x141414, 0xdff7f4, 0xf0f0ff) }
    static var parchmentMid: Color { pick(0xa6c8e2, 0xe0bc6c, 0xcfe4b8, 0xd4c29a, 0x9a9da9, 0xd6b98a, 0xc9a8ea, 0xd8a878, 0x3d3d3d, 0x8fc4c4, 0xa0a0d0) }
    static var parchmentDim: Color { pick(0x6f93b4, 0xc09838, 0x9bbf88, 0xa08f6e, 0x666974, 0xa8865c, 0x9670c4, 0xa87a52, 0x6b6b6b, 0x5a8c94, 0x6a6a9a) }
    static var ink: Color         { pick(0x04101e, 0x1a0c02, 0x08130c, 0x120c06, 0x030304, 0x140c05, 0x0d0418, 0x050302, 0xf4f1e8, 0x01060b, 0x000000) }

    // The halo/accent color used by the glow + panel modifiers. Tesla = electric-blue
    // accent. Steampunk = warm brass aura. Garden = soft green. Academia = green bloom.
    // Noir = bright ox-blood (rust) so the halo reads on near-black.
    static var glow: Color {
        switch mode {
        case .tesla:     return verdigris
        case .steampunk: return brass
        case .garden:    return Color(hex: 0x7cc24a)
        case .academia:  return Color(hex: 0x5a9e5d)
        case .noir:      return Color(hex: 0xc4202a)   // bright ox-blood halo on crypt-black
        case .west:      return Color(hex: 0xe0a33f)   // warm lantern gold, not the turquoise accent
        case .neon:      return Color(hex: 0xff4fd8)   // magenta neon tube
        case .forge:     return Color(hex: 0xff8a1f)   // heat bloom
        case .ransom:    return Color(hex: 0xff2d55)   // hot-pink marker; ink itself never glows
        case .abyss:     return Color(hex: 0x3dffc8)   // bioluminescent teal
        case .arcade:    return Color(hex: 0x39ff14)   // phosphor green
        }
    }

    // Bump all text larger app-wide (matches Android's LocalDensity fontScale).
    static let fontScale: CGFloat = 1.32
    // VT323 is a tall, thin terminal face that reads small next to the others.
    private static let vtScale: CGFloat = fontScale * 1.18

    // Per-theme typography. Steampunk = ornate serif (Cinzel Decorative / Cinzel / Lora,
    // from steampunk.css). Tesla = clean geometric sans (Orbitron display, Rajdhani UI/body).
    // All registered at runtime in ChroniclerApp; PostScript names verified via fontTools.
    // display = ONLY the "Chronicler" wordmark. serif = fixed UI titles/headers.
    // body = all content INCLUDING book titles.
    // Garden = signature script wordmark (Dancing Script) + rounded body (Quicksand).
    // PostScript names verified via fontTools (DancingScript-Regular, Quicksand-Light);
    // registered at runtime in ChroniclerApp. The display weight is bumped to .bold so the
    // flowing signature reads boldly.
    // Academia + Noir reuse the bundled serif family (Cinzel caps + Lora body) — both are
    // literary/serif looks. Academia leans elegant (plain Cinzel wordmark); Noir leans
    // dramatic (ornate Cinzel Decorative wordmark). Web gets the bespoke Cormorant/Playfair/
    // Pirata fonts; native falls back to the already-registered Cinzel/Lora.
    static func display(_ size: CGFloat) -> Font {
        switch mode {
        case .steampunk: return .custom("CinzelDecorative-Bold", size: size * fontScale)
        case .tesla:     return .custom("Orbitron-Bold", size: size * fontScale)
        case .garden:    return .custom("DancingScript-Regular", size: size * fontScale).weight(.bold)
        case .academia:  return .custom("Cinzel-Regular", size: size * fontScale).weight(.semibold)
        case .noir:      return .custom("UnifrakturMaguntia", size: size * fontScale)  // heavy blackletter
        case .west:      return .custom("Rye-Regular", size: size * fontScale)         // wood-type saloon
        case .neon:      return .custom("Monoton-Regular", size: size * fontScale)     // hollow neon tube
        case .forge:     return .custom("AlfaSlabOne-Regular", size: size * fontScale) // heavy molten slab
        case .ransom:    return .custom("SpecialElite-Regular", size: size * fontScale) // see RansomWordmark
        case .abyss:     return .custom("MajorMonoDisplay-Regular", size: size * fontScale) // thin mixed-case mono
        case .arcade:    return .custom("PressStart2P-Regular", size: size * fontScale)     // 8-bit cabinet
        }
    }
    static func serif(_ size: CGFloat) -> Font {
        switch mode {
        case .steampunk: return .custom("Cinzel-Regular", size: size * fontScale)
        case .tesla:     return .custom("Orbitron-Medium", size: size * fontScale)
        case .garden:    return .custom("Quicksand-Light", size: size * fontScale).weight(.medium)
        case .academia:  return .custom("Cinzel-Regular", size: size * fontScale)
        case .noir:      return .custom("Cinzel-Regular", size: size * fontScale)
        case .west:      return .custom("ZillaSlab-SemiBold", size: size * fontScale)
        case .neon:      return .custom("Michroma-Regular", size: size * fontScale)
        case .forge:     return .custom("ZillaSlab-SemiBold", size: size * fontScale)
        case .ransom:    return .custom("SpecialElite-Regular", size: size * fontScale)
        case .abyss:     return .custom("Quicksand-Light", size: size * fontScale).weight(.medium)
        case .arcade:    return .custom("VT323-Regular", size: size * vtScale)
        }
    }
    static func body(_ size: CGFloat) -> Font {
        switch mode {
        case .steampunk: return .custom("Lora-Regular", size: size * fontScale)
        case .tesla:     return .custom("Rajdhani-Medium", size: size * fontScale)
        case .garden:    return .custom("Quicksand-Light", size: size * fontScale)
        case .academia:  return .custom("Lora-Regular", size: size * fontScale)
        case .noir:      return .custom("Lora-Regular", size: size * fontScale)
        case .west:      return .custom("ZillaSlab-Regular", size: size * fontScale)
        // Michroma is very wide — body text stays Rajdhani so long titles still fit.
        case .neon:      return .custom("Rajdhani-Medium", size: size * fontScale)
        case .forge:     return .custom("ZillaSlab-Regular", size: size * fontScale)
        case .ransom:    return .custom("SpecialElite-Regular", size: size * fontScale)
        case .abyss:     return .custom("Quicksand-Light", size: size * fontScale)
        case .arcade:    return .custom("VT323-Regular", size: size * vtScale)
        }
    }
    // Lora bundles Regular only; bold synthesized. Rajdhani-Medium already reads bold.
    // Quicksand is variable — request .bold for emphasis.
    static func bodyBold(_ size: CGFloat) -> Font {
        switch mode {
        case .steampunk: return .custom("Lora-Regular", size: size * fontScale).weight(.bold)
        case .tesla:     return .custom("Rajdhani-Medium", size: size * fontScale).weight(.bold)
        case .garden:    return .custom("Quicksand-Light", size: size * fontScale).weight(.bold)
        case .academia:  return .custom("Lora-Regular", size: size * fontScale).weight(.bold)
        case .noir:      return .custom("Lora-Regular", size: size * fontScale).weight(.bold)
        case .west:      return .custom("ZillaSlab-SemiBold", size: size * fontScale)
        case .neon:      return .custom("Michroma-Regular", size: size * fontScale)
        case .forge:     return .custom("AlfaSlabOne-Regular", size: size * fontScale)
        case .ransom:    return .custom("SpecialElite-Regular", size: size * fontScale)
        case .abyss:     return .custom("Quicksand-Light", size: size * fontScale).weight(.bold)
        // VT323 has one weight; a synthesized bold smears the pixels, so it stays regular.
        case .arcade:    return .custom("VT323-Regular", size: size * vtScale)
        }
    }

    static var brassGradient: LinearGradient {
        LinearGradient(colors: [brassLight, brass, borderBrass],
                       startPoint: .top, endPoint: .bottom)
    }
}

// Persists the theme choice + drives a full re-render of the root view. Static
// computed colors won't recompose on their own, so ChroniclerApp keys the root on
// `mode` via `.id(themeStore.mode)`.
final class ThemeStore: ObservableObject {
    private static let key = "chronicler.theme"

    @Published var mode: ThemeMode {
        didSet {
            Theme.mode = mode
            UserDefaults.standard.set(mode.rawValue, forKey: Self.key)
            // Play the newly-selected theme's sound immediately (didSet does not fire on
            // init, so this is only user-driven switches, not launch).
            StartupSound.shared.play(force: true)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        let m = raw.flatMap(ThemeMode.init(rawValue:)) ?? .tesla
        self.mode = m
        Theme.mode = m
    }
}

// Breathing electric-blue aura on headings/titles — triple-stacked halo whose
// brightness + radius pulse forever. Animated via a repeating value animation
// (NOT a per-frame subtree rebuild), so it stays cheap even across the grid.
// Steampunk: a STEADY brass halo with no pulsing (no electricity).
private struct ElectricGlow: ViewModifier {
    let tight: CGFloat, mid: CGFloat, wide: CGFloat
    @State private var on = false
    func body(content: Content) -> some View {
        // Paper does not glow. Ransom gets a hard ink offset instead of a halo — a
        // bloom on a photocopy just reads as a smudge.
        if Theme.mode == .ransom {
            content.shadow(color: .black.opacity(0.4), radius: 0, x: 1, y: 1)
        // Arcade: no blur on a pixel screen — a hard pink offset, like a sprite's drop shadow.
        } else if Theme.mode == .arcade {
            content.shadow(color: Theme.copper, radius: 0, x: 2, y: 2)
        // Abyss: a teal halo that breathes slowly, like something alive in the dark.
        } else if Theme.mode == .abyss {
            content
                .shadow(color: Theme.glow.opacity(on ? 0.85 : 0.45), radius: on ? tight * 1.4 : tight)
                .shadow(color: Theme.glow.opacity(on ? 0.5 : 0.25),  radius: on ? mid * 1.4 : mid)
                .shadow(color: Theme.glow.opacity(on ? 0.3 : 0.12),  radius: on ? wide * 1.3 : wide)
                .onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { on = true } }
        // Steady halo everywhere except the two electric themes (Tesla, Neon).
        } else if Theme.mode != .tesla && Theme.mode != .neon {
            content
                .shadow(color: Theme.glow.opacity(0.7), radius: tight)
                .shadow(color: Theme.glow.opacity(0.38), radius: mid)
                .shadow(color: Theme.glow.opacity(0.2),  radius: wide)
        } else {
            content
                .shadow(color: Theme.glow.opacity(on ? 1.0 : 0.6),  radius: on ? tight * 1.5 : tight)
                .shadow(color: Theme.glow.opacity(on ? 0.8 : 0.42), radius: on ? mid * 1.5 : mid)
                .shadow(color: Theme.glow.opacity(on ? 0.5 : 0.22), radius: on ? wide * 1.5 : wide)
                .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { on = true } }
        }
    }
}

// Electric-blue panel with a pulsing border + breathing drop-glow. Filled background,
// clipped, then an animated stroke + stacked halo on top. Mirrors Android's electricPanel.
// Steampunk: a STEADY brass-bordered panel — no pulse, no traveling current.
private struct ElectricPanelStyle: ViewModifier {
    let bg: Color, corner: CGFloat, alpha: Double, glowRadius: CGFloat
    @State private var on = false
    func body(content: Content) -> some View {
        if Theme.mode == .garden {
            // Garden: a frosted-TRANSLUCENT green panel — a faint green tint over thin
            // material so the vector-flower wallpaper reads softly through it. Generous
            // corner radius, gentle green border + soft bloom. No rivets, no current.
            let gardenCorner = max(corner, 16)
            content
                .background(bg.opacity(0.5))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: gardenCorner))
                .overlay(RoundedRectangle(cornerRadius: gardenCorner)
                    .stroke(Theme.glow.opacity(min(1, alpha)), lineWidth: 1.4))
                .shadow(color: Theme.glow.opacity(0.32), radius: glowRadius * 1.3)
                .shadow(color: Theme.glow.opacity(0.14), radius: glowRadius * 2.4)
        } else if Theme.mode == .steampunk {
            // Slightly translucent: a lower brass-fill alpha over thin material so the
            // factory skyline + steam read softly through the panel, while staying legible.
            // Tight 2pt corners (match web/Android).
            let steampunkCorner: CGFloat = 2
            content
                .background(bg.opacity(0.42))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: steampunkCorner))
                .overlay(RoundedRectangle(cornerRadius: steampunkCorner)
                    .stroke(Theme.glow.opacity(min(1, alpha * 1.2)), lineWidth: 1.8))
                .shadow(color: Theme.glow.opacity(0.4), radius: glowRadius)
                .shadow(color: Theme.glow.opacity(0.18), radius: glowRadius * 1.8)
        } else if Theme.mode == .academia {
            // Academia: a quiet leather-and-lamplight panel — softly squared corners,
            // brass-green border, steady warm bloom. No pulse, no current.
            let c: CGFloat = 6
            content
                .background(bg.opacity(0.55))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: c))
                .overlay(RoundedRectangle(cornerRadius: c)
                    .stroke(Theme.borderBrass.opacity(min(1, alpha)), lineWidth: 1.2))
                .shadow(color: Theme.glow.opacity(0.3), radius: glowRadius * 1.2)
                .shadow(color: Theme.glow.opacity(0.12), radius: glowRadius * 2.2)
        } else if Theme.mode == .noir {
            // Noir: sharp gothic plate — hard right-angle corners, thin tarnished-silver
            // edge, a hard black drop shadow + a tight ox-blood rim. No pulse, no current.
            content
                .background(bg.opacity(0.66))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .overlay(RoundedRectangle(cornerRadius: 0)
                    .stroke(Theme.borderBrass.opacity(min(1, alpha * 1.1)), lineWidth: 1.0))
                .shadow(color: .black.opacity(0.85), radius: glowRadius * 0.7, x: 0, y: 6)
                .shadow(color: Theme.glow.opacity(0.32), radius: glowRadius)
        } else if Theme.mode == .neon {
            // Neon: a chrome-bevelled slab — magenta outer bloom, cyan inner rim, and a
            // bright edge that breathes like a tube warming up. Rounded like an 80s dashboard.
            let c: CGFloat = 12
            content
                .background(bg.opacity(0.5))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: c))
                .overlay(RoundedRectangle(cornerRadius: c)
                    .stroke(Theme.copper.opacity(min(1, alpha)), lineWidth: 1))          // cyan inner
                .overlay(RoundedRectangle(cornerRadius: c)
                    .stroke(Theme.brass.opacity(on ? min(1, alpha * 1.5) : alpha * 0.8),
                            lineWidth: on ? 2.4 : 1.6))                                   // magenta edge
                .shadow(color: Theme.brass.opacity(on ? 0.8 : 0.45), radius: on ? glowRadius * 1.7 : glowRadius)
                .shadow(color: Theme.copper.opacity(0.35), radius: glowRadius * 2.2)
                .onAppear { withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { on = true } }
        } else if Theme.mode == .forge {
            // Forge: a branded iron plate — hard corners, an edge that cools from white-hot
            // at the top to red at the bottom, and a heavy heat bloom under it.
            content
                .background(bg.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .overlay(RoundedRectangle(cornerRadius: 1)
                    .stroke(LinearGradient(colors: [Theme.verdigris.opacity(min(1, alpha * 1.2)),
                                                    Theme.brass.opacity(min(1, alpha)),
                                                    Theme.rust.opacity(min(1, alpha * 0.9))],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.8))
                .shadow(color: Theme.brass.opacity(0.5), radius: glowRadius * 1.3)
                .shadow(color: Theme.rust.opacity(0.3), radius: glowRadius * 2.4)
        } else if Theme.mode == .ransom {
            // Ransom: an off-white card with a hard black offset shadow and a deliberate
            // half-degree tilt, like something taped onto the page. No glow — it's paper.
            content
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .overlay(RoundedRectangle(cornerRadius: 1)
                    .stroke(Theme.parchment.opacity(0.85), lineWidth: 1.5))
                .shadow(color: Theme.parchment.opacity(0.9), radius: 0, x: 3, y: 3)
                .rotationEffect(.degrees(-0.5))
        } else if Theme.mode == .abyss {
            // Abyss: a soft membrane — deep rounded corners, a teal edge that breathes
            // slowly like a jellyfish bell, and a violet bloom spreading out into the water.
            let c = max(corner, 18)
            content
                .background(bg.opacity(0.5))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: c))
                .overlay(RoundedRectangle(cornerRadius: c)
                    .stroke(Theme.brass.opacity(on ? min(1, alpha * 1.2) : alpha * 0.55), lineWidth: 1.4))
                .shadow(color: Theme.copper.opacity(0.34), radius: glowRadius * 1.4)
                .shadow(color: Theme.copper.opacity(0.14), radius: glowRadius * 2.6)
                .onAppear { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { on = true } }
        } else if Theme.mode == .arcade {
            // Arcade: a cabinet bezel — square corners, thick solid yellow frame, and a
            // hard green offset shadow with zero blur. No material; pixels aren't frosted.
            // Black under the fill so the offset shadow can't bleed through the 12% gap.
            content
                .background(bg.opacity(0.88))
                .background(Color.black)
                .clipShape(Rectangle())
                .overlay(Rectangle().stroke(Theme.brass, lineWidth: 3))
                .shadow(color: Theme.verdigris, radius: 0, x: 4, y: 4)
        } else if Theme.mode == .west {
            // West: a weathered board nailed to the wall — squared corners, thick sun-baked
            // leather edge, a warm dusk bloom and a faint turquoise rim. No pulse, no current.
            let c: CGFloat = 3
            content
                .background(bg.opacity(0.62))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: c))
                .overlay(RoundedRectangle(cornerRadius: c)
                    .stroke(Theme.borderBrass.opacity(min(1, alpha * 1.15)), lineWidth: 1.6))
                .shadow(color: Color.black.opacity(0.6), radius: glowRadius * 0.6, x: 0, y: 4)
                .shadow(color: Theme.glow.opacity(0.26), radius: glowRadius * 1.1)
        } else {
            // Tesla: frosted GLASS — translucent material over a faint blue fill, soft
            // rounded corners, a thin bright cyan border + pulsing halo, racing current.
            let teslaCorner = max(corner, 10)
            content
                .background(bg.opacity(0.28))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: teslaCorner))
                .overlay(RoundedRectangle(cornerRadius: teslaCorner)
                    .stroke(Theme.glow.opacity(on ? min(1, alpha * 1.6) : alpha * 0.9),
                            lineWidth: on ? 2.0 : 1.2))
                .shadow(color: Theme.glow.opacity(on ? 0.85 : 0.45), radius: on ? glowRadius * 1.8 : glowRadius)
                .shadow(color: Theme.glow.opacity(on ? 0.45 : 0.2),  radius: on ? glowRadius * 2.9 : glowRadius * 1.8)
                .travelingCurrent(corner: teslaCorner)   // bright arc of current racing the border
                .onAppear { withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { on = true } }
        }
    }
}

extension View {
    func glowVerdigris() -> some View { modifier(ElectricGlow(tight: 5, mid: 13, wide: 26)) }

    func electricPanel(bg: Color = Theme.surface,
                       corner: CGFloat = 4,
                       alpha: Double = 0.6,
                       glowRadius: CGFloat = 14) -> some View {
        modifier(ElectricPanelStyle(bg: bg, corner: corner, alpha: alpha, glowRadius: glowRadius))
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha)
    }
}

// Shared time formatter matching FormatTime in the Blazor components.
func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                 : String(format: "%d:%02d", m, s)
}
