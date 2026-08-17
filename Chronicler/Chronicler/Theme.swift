import SwiftUI
import Combine

// Six runtime themes. Tesla = electric-blue look; Steampunk = Victorian brass/gold
// with NO electricity; Garden = verdant greens + floral pink, soft/organic, NO electricity.
// Academia = espresso/forest-green/cream/brass, rainy-university serif, NO electricity.
// Noir = black/ox-blood/cold-gray/tarnished-silver, gothic, sharp shadows, NO electricity.
// West = sun-bleached desert dusk: leather browns, sheriff-star gold, turquoise accent,
// wood-type lettering, NO electricity.
// Mirrors the web frontend's theme switcher.
enum ThemeMode: String { case tesla, steampunk, garden, academia, noir, west }

// Themed palette. Colors are computed properties that switch on `Theme.mode`.
// TESLA values are the original hardcoded set; STEAMPUNK is a warmer brass set
// with a GREEN accent (verdigris) instead of the electric blue.
enum Theme {
    // Live theme. Mutated by ThemeStore; views re-render via `.id(themeStore.mode)`.
    static var mode: ThemeMode = .tesla

    private static var s: Bool { mode == .steampunk }
    private static var g: Bool { mode == .garden }

    // Six-way palette pick: tesla / steampunk / garden / academia / noir / west.
    private static func pick(_ tesla: UInt, _ steampunk: UInt, _ garden: UInt,
                             _ academia: UInt, _ noir: UInt, _ west: UInt) -> Color {
        switch mode {
        case .tesla:     return Color(hex: tesla)
        case .steampunk: return Color(hex: steampunk)
        case .garden:    return Color(hex: garden)
        case .academia:  return Color(hex: academia)
        case .noir:      return Color(hex: noir)
        case .west:      return Color(hex: west)
        }
    }

    // Tesla = cold electric-blue glass. Steampunk = warm brass/leather. Garden = verdant
    // greens (metal→foliage, accent→floral pink). Academia = espresso wood, brass metal,
    // cream text, forest-green accent. Noir = near-black, tarnished-silver metal, cold-gray
    // text, ox-blood accent.
    //                            ( tesla   ,  steampunk,  garden  ,  academia,  noir    ,  west    )
    static var bg: Color          { pick(0x05080f, 0x160d03, 0x0b1410, 0x161009, 0x040406, 0x150e08) }
    static var bg2: Color         { pick(0x090e1a, 0x1e1206, 0x0f1c14, 0x1d150c, 0x08080b, 0x1f150c) }
    static var leather: Color     { pick(0x0b1424, 0x281809, 0x12241a, 0x2a1d10, 0x0c0c10, 0x2b1d10) }
    static var surface: Color     { pick(0x0f1a2e, 0x32200c, 0x16301f, 0x2f2211, 0x101015, 0x362514) }
    static var surface2: Color    { pick(0x142440, 0x3e280e, 0x1d3d28, 0x3a2b16, 0x17171e, 0x442f1a) }
    static var surface3: Color    { pick(0x1b3052, 0x4a3012, 0x245031, 0x46351c, 0x212129, 0x543a20) }
    static var border: Color      { pick(0x21405f, 0x6b4420, 0x2f5c3c, 0x5a4527, 0x2e2e38, 0x6d4a28) }
    static var borderBrass: Color { pick(0x3f86b8, 0xc08828, 0x6fae5f, 0x9a7b3e, 0x7e818c, 0xc08a45) }  // trim
    // The "brass"/metal: Tesla electric-blue chrome, Steampunk gold, Garden foliage green,
    // Academia antique brass, Noir bone/tarnished silver (buttons + wordmark).
    static var brass: Color       { pick(0x2bc4ff, 0xe09808, 0x8bd450, 0xc39a4e, 0xc4c8d2, 0xd9a441) }
    static var brassLight: Color  { pick(0x7fe0ff, 0xffc838, 0xb6f07a, 0xe3c275, 0xe2e5ec, 0xf0c46f) }
    static var brassPale: Color   { pick(0xd6f4ff, 0xffe878, 0xe2ffc0, 0xf4e6b8, 0xf2f4f8, 0xffe3ab) }
    static var copper: Color      { pick(0x1f9fd8, 0xc86818, 0xe88fa8, 0x7d9b6a, 0x6e0d13, 0xb4552b) }
    static var copperLight: Color { pick(0x5ac8ff, 0xe88838, 0xffb0c8, 0xa3c089, 0x9c1820, 0xd97a45) }
    static var rust: Color        { pick(0xff5470, 0xb82c0c, 0xd4564a, 0xa23b22, 0xc41019, 0xc0392b) }
    // Accent / "electric" color. Tesla = electric blue (drives glow + panel). Steampunk =
    // verdigris green. Garden = floral PINK. Academia = forest green. Noir = ox-blood red.
    static var verdigris: Color   { pick(0x2bc4ff, 0x8fd44a, 0xff8fb8, 0x4f8a52, 0xa8121b, 0x3fb0a3) }
    static var parchment: Color   { pick(0xe6f3ff, 0xf6ecd0, 0xf0f7e8, 0xf2e7cf, 0xd9dbe2, 0xf3e3c3) }
    static var parchmentMid: Color { pick(0xa6c8e2, 0xe0bc6c, 0xcfe4b8, 0xd4c29a, 0x9a9da9, 0xd6b98a) }
    static var parchmentDim: Color { pick(0x6f93b4, 0xc09838, 0x9bbf88, 0xa08f6e, 0x666974, 0xa8865c) }
    static var ink: Color         { pick(0x04101e, 0x1a0c02, 0x08130c, 0x120c06, 0x030304, 0x140c05) }

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
        }
    }

    // Bump all text larger app-wide (matches Android's LocalDensity fontScale).
    static let fontScale: CGFloat = 1.32

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
        // Steampunk + Garden: a STEADY halo (no electricity). Tesla: pulsing.
        if Theme.mode != .tesla {
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
