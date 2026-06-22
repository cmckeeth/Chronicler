import SwiftUI
import CoreText

@main
struct ChroniclerApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var themeStore = ThemeStore()

    init() {
        Self.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(themeStore)
                // Static computed theme colors won't recompose on their own — key the
                // whole tree on the mode so switching forces a full re-render.
                .id(themeStore.mode)
        }
    }

    // Register the bundled steampunk fonts at runtime so Font.custom(...) resolves
    // them without an Info.plist UIAppFonts entry (this project has no Info.plist).
    private static func registerFonts() {
        let names = [
            // Steampunk: ornate serif.
            "CinzelDecorative-Regular",
            "CinzelDecorative-Bold",
            "CinzelDecorative-Black",
            "Cinzel",
            "Lora",
            // Tesla: clean geometric sans (Orbitron display, Rajdhani UI/body).
            "Orbitron-Bold",
            "Orbitron-Medium",
            "Rajdhani-Regular",
            "Rajdhani-Medium",
        ]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
