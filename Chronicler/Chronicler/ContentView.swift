import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var themeStore: ThemeStore

    var body: some View {
        Group {
            if auth.isAuthenticated {
                NavigationStack {
                    LandingView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .archive: ArchiveView()
                            case .book(let book): BookPlayerView(bookId: book.id)
                            case .collection(let c): CollectionView(collection: c)
                            case .offline: OfflineLibraryView()
                            }
                        }
                }
                .tint(Theme.brass)
            } else {
                LoginView()
            }
        }
        // Ransom Note is a LIGHT theme, and system-drawn chrome (text-field placeholders,
        // picker labels) follows the colour scheme rather than our palette — forcing dark
        // there made the search placeholder invisible on paper.
        .preferredColorScheme(themeStore.mode == .ransom ? .light : .dark)
    }
}

#Preview {
    ContentView().environmentObject(AuthStore()).environmentObject(ThemeStore())
}
