import SwiftUI
import CoreText

@main
struct ChroniclerApp: App {
    @StateObject private var auth = AuthStore()

    init() {
        Self.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }

    // Register the bundled steampunk fonts at runtime so Font.custom(...) resolves
    // them without an Info.plist UIAppFonts entry (this project has no Info.plist).
    private static func registerFonts() {
        let names = [
            "CinzelDecorative-Regular",
            "CinzelDecorative-Bold",
            "CinzelDecorative-Black",
            "Cinzel",
            "Lora",
        ]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
