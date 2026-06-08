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

    // Fonts ported from steampunk.css: Cinzel Decorative (display), Cinzel (serif), Lora (body).
    // Registered at runtime in ChroniclerApp; PostScript names verified via fontTools.
    static func display(_ size: CGFloat) -> Font { .custom("CinzelDecorative-Bold", size: size) }
    static func serif(_ size: CGFloat) -> Font { .custom("Cinzel-Regular", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("Lora-Regular", size: size) }

    static let brassGradient = LinearGradient(
        colors: [brassLight, brass, borderBrass],
        startPoint: .top, endPoint: .bottom)
}

// --glow-brass: 0 0 20px #e8a010 — the "electric" brass glow on headings/titles.
extension View {
    func glowBrass() -> some View {
        self
            .shadow(color: Theme.brass.opacity(0.85), radius: 12)
            .shadow(color: Theme.brass.opacity(0.45), radius: 24)
    }

    func glowVerdigris() -> some View {
        self.shadow(color: Theme.verdigris.opacity(0.6), radius: 8)
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
