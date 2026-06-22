import SwiftUI
import Combine

// Two runtime themes. Tesla = current electric-blue look; Steampunk = Victorian
// brass/gold with NO electricity. Mirrors the web frontend's theme switcher.
enum ThemeMode: String { case tesla, steampunk }

// Themed palette. Colors are computed properties that switch on `Theme.mode`.
// TESLA values are the original hardcoded set; STEAMPUNK is a warmer brass set
// with a GREEN accent (verdigris) instead of the electric blue.
enum Theme {
    // Live theme. Mutated by ThemeStore; views re-render via `.id(themeStore.mode)`.
    static var mode: ThemeMode = .tesla

    private static var s: Bool { mode == .steampunk }

    // Steampunk = warm brass/leather (FIRST value). Tesla = cold electric-blue glass
    // (SECOND value) — a dark blue-black world where "brass"/metal becomes chrome-blue.
    static var bg: Color          { s ? Color(hex: 0x160d03) : Color(hex: 0x05080f) }
    static var bg2: Color         { s ? Color(hex: 0x1e1206) : Color(hex: 0x090e1a) }
    static var leather: Color     { s ? Color(hex: 0x281809) : Color(hex: 0x0b1424) }
    static var surface: Color     { s ? Color(hex: 0x32200c) : Color(hex: 0x0f1a2e) }
    static var surface2: Color    { s ? Color(hex: 0x3e280e) : Color(hex: 0x142440) }
    static var surface3: Color    { s ? Color(hex: 0x4a3012) : Color(hex: 0x1b3052) }
    static var border: Color      { s ? Color(hex: 0x6b4420) : Color(hex: 0x21405f) }
    static var borderBrass: Color { s ? Color(hex: 0xc08828) : Color(hex: 0x3f86b8) }  // steel trim
    // The "brass"/metal: Steampunk gold, Tesla electric-blue chrome (buttons + wordmark).
    static var brass: Color       { s ? Color(hex: 0xe09808) : Color(hex: 0x2bc4ff) }
    static var brassLight: Color  { s ? Color(hex: 0xffc838) : Color(hex: 0x7fe0ff) }
    static var brassPale: Color   { s ? Color(hex: 0xffe878) : Color(hex: 0xd6f4ff) }
    static var copper: Color      { s ? Color(hex: 0xc86818) : Color(hex: 0x1f9fd8) }
    static var copperLight: Color { s ? Color(hex: 0xe88838) : Color(hex: 0x5ac8ff) }
    static var rust: Color        { s ? Color(hex: 0xb82c0c) : Color(hex: 0xff5470) }
    // Accent / "electric" color. Tesla = vivid electric blue (drives every glow +
    // panel). Steampunk = verdigris GREEN — the key accent flip.
    static var verdigris: Color   { s ? Color(hex: 0x8fd44a) : Color(hex: 0x2bc4ff) }
    static var parchment: Color   { s ? Color(hex: 0xf6ecd0) : Color(hex: 0xe6f3ff) }
    static var parchmentMid: Color { s ? Color(hex: 0xe0bc6c) : Color(hex: 0xa6c8e2) }
    static var parchmentDim: Color { s ? Color(hex: 0xc09838) : Color(hex: 0x6f93b4) }
    static var ink: Color         { s ? Color(hex: 0x1a0c02) : Color(hex: 0x04101e) }

    // The halo/accent color used by the glow + panel modifiers. Steampunk uses a
    // warm brass aura (NOT the green accent); Tesla uses the electric blue accent.
    static var glow: Color { s ? brass : verdigris }

    // Bump all text larger app-wide (matches Android's LocalDensity fontScale).
    static let fontScale: CGFloat = 1.32

    // Per-theme typography. Steampunk = ornate serif (Cinzel Decorative / Cinzel / Lora,
    // from steampunk.css). Tesla = clean geometric sans (Orbitron display, Rajdhani UI/body).
    // All registered at runtime in ChroniclerApp; PostScript names verified via fontTools.
    // display = ONLY the "Chronicler" wordmark. serif = fixed UI titles/headers.
    // body = all content INCLUDING book titles.
    static func display(_ size: CGFloat) -> Font {
        s ? .custom("CinzelDecorative-Bold", size: size * fontScale)
          : .custom("Orbitron-Bold", size: size * fontScale)
    }
    static func serif(_ size: CGFloat) -> Font {
        s ? .custom("Cinzel-Regular", size: size * fontScale)
          : .custom("Orbitron-Medium", size: size * fontScale)
    }
    static func body(_ size: CGFloat) -> Font {
        s ? .custom("Lora-Regular", size: size * fontScale)
          : .custom("Rajdhani-Medium", size: size * fontScale)
    }
    // Lora bundles Regular only; bold synthesized. Rajdhani-Medium already reads bold.
    static func bodyBold(_ size: CGFloat) -> Font {
        s ? .custom("Lora-Regular", size: size * fontScale).weight(.bold)
          : .custom("Rajdhani-Medium", size: size * fontScale).weight(.bold)
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
        if Theme.mode == .steampunk {
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
        if Theme.mode == .steampunk {
            content
                .background(bg.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner)
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
