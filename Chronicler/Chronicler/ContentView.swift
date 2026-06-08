import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        Group {
            if auth.isAuthenticated {
                NavigationStack {
                    LandingView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .archive: ArchiveView()
                            case .book(let book): BookPlayerView(bookId: book.id)
                            }
                        }
                }
                .tint(Theme.brass)
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView().environmentObject(AuthStore())
}
