import SwiftUI
import Combine

// Three runtime themes. Tesla = electric-blue look; Steampunk = Victorian brass/gold
// with NO electricity; Garden = verdant greens + floral pink, soft/organic, NO electricity.
// Mirrors the web frontend's theme switcher.
enum ThemeMode: String { case tesla, steampunk, garden }

// Themed palette. Colors are computed properties that switch on `Theme.mode`.
// TESLA values are the original hardcoded set; STEAMPUNK is a warmer brass set
// with a GREEN accent (verdigris) instead of the electric blue.
enum Theme {
    // Live theme. Mutated by ThemeStore; views re-render via `.id(themeStore.mode)`.
    static var mode: ThemeMode = .tesla

    private static var s: Bool { mode == .steampunk }
    private static var g: Bool { mode == .garden }

    // Three-way palette pick: tesla / steampunk / garden.
    private static func pick(_ tesla: UInt, _ steampunk: UInt, _ garden: UInt) -> Color {
        switch mode {
        case .tesla:     return Color(hex: tesla)
        case .steampunk: return Color(hex: steampunk)
        case .garden:    return Color(hex: garden)
        }
    }

    // Tesla = cold electric-blue glass. Steampunk = warm brass/leather. Garden = verdant
    // greens, the "metal" becomes foliage green and the accent becomes floral pink.
    //                            ( tesla   ,  steampunk,  garden  )
    static var bg: Color          { pick(0x05080f, 0x160d03, 0x0b1410) }
    static var bg2: Color         { pick(0x090e1a, 0x1e1206, 0x0f1c14) }
    static var leather: Color     { pick(0x0b1424, 0x281809, 0x12241a) }
    static var surface: Color     { pick(0x0f1a2e, 0x32200c, 0x16301f) }
    static var surface2: Color    { pick(0x142440, 0x3e280e, 0x1d3d28) }
    static var surface3: Color    { pick(0x1b3052, 0x4a3012, 0x245031) }
    static var border: Color      { pick(0x21405f, 0x6b4420, 0x2f5c3c) }
    static var borderBrass: Color { pick(0x3f86b8, 0xc08828, 0x6fae5f) }  // trim
    // The "brass"/metal: Tesla electric-blue chrome, Steampunk gold, Garden foliage green
    // (buttons + wordmark).
    static var brass: Color       { pick(0x2bc4ff, 0xe09808, 0x8bd450) }
    static var brassLight: Color  { pick(0x7fe0ff, 0xffc838, 0xb6f07a) }
    static var brassPale: Color   { pick(0xd6f4ff, 0xffe878, 0xe2ffc0) }
    static var copper: Color      { pick(0x1f9fd8, 0xc86818, 0xe88fa8) }
    static var copperLight: Color { pick(0x5ac8ff, 0xe88838, 0xffb0c8) }
    static var rust: Color        { pick(0xff5470, 0xb82c0c, 0xd4564a) }
    // Accent / "electric" color. Tesla = electric blue (drives glow + panel). Steampunk =
    // verdigris green. Garden = floral PINK — badges/active/accents.
    static var verdigris: Color   { pick(0x2bc4ff, 0x8fd44a, 0xff8fb8) }
    static var parchment: Color   { pick(0xe6f3ff, 0xf6ecd0, 0xf0f7e8) }
    static var parchmentMid: Color { pick(0xa6c8e2, 0xe0bc6c, 0xcfe4b8) }
    static var parchmentDim: Color { pick(0x6f93b4, 0xc09838, 0x9bbf88) }
    static var ink: Color         { pick(0x04101e, 0x1a0c02, 0x08130c) }

    // The halo/accent color used by the glow + panel modifiers. Tesla = electric-blue
    // accent. Steampunk = warm brass aura (NOT the green accent). Garden = soft green
    // (NOT the floral-pink accent) — heading/panel bloom.
    static var glow: Color { g ? Color(hex: 0x7cc24a) : (s ? brass : verdigris) }

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
    static func display(_ size: CGFloat) -> Font {
        switch mode {
        case .steampunk: return .custom("CinzelDecorative-Bold", size: size * fontScale)
        case .tesla:     return .custom("Orbitron-Bold", size: size * fontScale)
        case .garden:    return .custom("DancingScript-Regular", size: size * fontScale).weight(.bold)
        }
    }
    static func serif(_ size: CGFloat) -> Font {
        switch mode {
        case .steampunk: return .custom("Cinzel-Regular", size: size * fontScale)
        case .tesla:     return .custom("Orbitron-Medium", size: size * fontScale)
        case .garden:    return .custom("Quicksand-Light", size: size * fontScale).weight(.medium)
        }
    }
    static func body(_ size: CGFloat) -> Font {
        switch mode {
        case .steampunk: return .custom("Lora-Regular", size: size * fontScale)
        case .tesla:     return .custom("Rajdhani-Medium", size: size * fontScale)
        case .garden:    return .custom("Quicksand-Light", size: size * fontScale)
        }
    }
    // Lora bundles Regular only; bold synthesized. Rajdhani-Medium already reads bold.
    // Quicksand is variable — request .bold for emphasis.
    static func bodyBold(_ size: CGFloat) -> Font {
        switch mode {
        case .steampunk: return .custom("Lora-Regular", size: size * fontScale).weight(.bold)
        case .tesla:     return .custom("Rajdhani-Medium", size: size * fontScale).weight(.bold)
        case .garden:    return .custom("Quicksand-Light", size: size * fontScale).weight(.bold)
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
