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
    static let verdigris   = Color(hex: 0x8fd44a)
    static let parchment   = Color(hex: 0xfff4d8)
    static let parchmentMid = Color(hex: 0xe8c878)
    static let parchmentDim = Color(hex: 0xc8a048)
    static let ink         = Color(hex: 0x1a0c02)

    // Bump all text ~20% larger app-wide (matches Android's LocalDensity fontScale * 1.2f).
    static let fontScale: CGFloat = 1.2

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

// Green-electric glow on headings/titles (was brass; now verdigris to match Android).
extension View {
    func glowVerdigris() -> some View {
        self
            .shadow(color: Theme.verdigris.opacity(0.9), radius: 8)
            .shadow(color: Theme.verdigris.opacity(0.5), radius: 16)
    }

    // Green-electric panel: verdigris drop-glow + filled background + verdigris border.
    // Mirrors Android's Modifier.electricPanel. Slap it on containers for the electric rizz.
    func electricPanel(bg: Color = Theme.surface,
                       corner: CGFloat = 4,
                       alpha: Double = 0.6,
                       glowRadius: CGFloat = 14) -> some View {
        self
            .background(bg.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner)
                .stroke(Theme.verdigris.opacity(alpha), lineWidth: 1.5))
            .shadow(color: Theme.verdigris.opacity(0.5), radius: glowRadius)
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
