import SwiftUI

// Steampunk palette ported from steampunk.css :root
enum Theme {
    static let bg          = Color(hex: 0x120a02)
    static let bg2         = Color(hex: 0x1a1005)
    static let leather     = Color(hex: 0x221408)
    static let surface     = Color(hex: 0x2a1a0a)
    static let surface2    = Color(hex: 0x341f0c)
    static let surface3    = Color(hex: 0x3e260e)
    static let border      = Color(hex: 0x5a3418)
    static let borderBrass = Color(hex: 0xb87c20)
    static let brass       = Color(hex: 0xe8a010)
    static let brassLight  = Color(hex: 0xffc030)
    static let brassPale   = Color(hex: 0xffe060)
    static let copper      = Color(hex: 0xd07020)
    static let copperLight = Color(hex: 0xf09040)
    static let rust        = Color(hex: 0xc03010)
    // Accent / "electric" color. Token name kept (used ~36 places) but repointed
    // from verdigris green to a vivid electric blue — drives every glow + panel.
    static let verdigris   = Color(hex: 0x2bc4ff)
    static let parchment   = Color(hex: 0xfff4d8)
    static let parchmentMid = Color(hex: 0xe8c878)
    static let parchmentDim = Color(hex: 0xc8a048)
    static let ink         = Color(hex: 0x1a0c02)

    // Bump all text larger app-wide (matches Android's LocalDensity fontScale).
    static let fontScale: CGFloat = 1.32

    // Fonts ported from steampunk.css: Cinzel Decorative (display), Cinzel (serif), Lora (body).
    // Registered at runtime in ChroniclerApp; PostScript names verified via fontTools.
    // display = ONLY the "Chronicler" wordmark. serif = fixed UI titles/headers.
    // body = all content INCLUDING book titles.
    static func display(_ size: CGFloat) -> Font { .custom("CinzelDecorative-Bold", size: size * fontScale) }
    static func serif(_ size: CGFloat) -> Font { .custom("Cinzel-Regular", size: size * fontScale) }
    static func body(_ size: CGFloat) -> Font { .custom("Lora-Regular", size: size * fontScale) }
    // Lora.ttf only bundles the Regular weight; bold is synthesized via .weight(.bold).
    static func bodyBold(_ size: CGFloat) -> Font { .custom("Lora-Regular", size: size * fontScale).weight(.bold) }

    static let brassGradient = LinearGradient(
        colors: [brassLight, brass, borderBrass],
        startPoint: .top, endPoint: .bottom)
}

// Breathing electric-blue aura on headings/titles — triple-stacked halo whose
// brightness + radius pulse forever. Animated via a repeating value animation
// (NOT a per-frame subtree rebuild), so it stays cheap even across the grid.
private struct ElectricGlow: ViewModifier {
    let tight: CGFloat, mid: CGFloat, wide: CGFloat
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .shadow(color: Theme.verdigris.opacity(on ? 1.0 : 0.6),  radius: on ? tight * 1.5 : tight)
            .shadow(color: Theme.verdigris.opacity(on ? 0.8 : 0.42), radius: on ? mid * 1.5 : mid)
            .shadow(color: Theme.verdigris.opacity(on ? 0.5 : 0.22), radius: on ? wide * 1.5 : wide)
            .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { on = true } }
    }
}

// Electric-blue panel with a pulsing border + breathing drop-glow. Filled background,
// clipped, then an animated stroke + stacked halo on top. Mirrors Android's electricPanel.
private struct ElectricPanelStyle: ViewModifier {
    let bg: Color, corner: CGFloat, alpha: Double, glowRadius: CGFloat
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .background(bg.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner)
                .stroke(Theme.verdigris.opacity(on ? min(1, alpha * 1.6) : alpha * 0.9),
                        lineWidth: on ? 2.6 : 1.6))
            .shadow(color: Theme.verdigris.opacity(on ? 0.85 : 0.45), radius: on ? glowRadius * 1.8 : glowRadius)
            .shadow(color: Theme.verdigris.opacity(on ? 0.45 : 0.2),  radius: on ? glowRadius * 2.9 : glowRadius * 1.8)
            .travelingCurrent(corner: corner)   // bright arc of current racing the border
            .onAppear { withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { on = true } }
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
