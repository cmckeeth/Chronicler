import SwiftUI

enum Route: Hashable {
    case archive
    case book(Book)
}

struct LandingView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ElectricBackground(intensity: 2.2)   // homepage should be buzzin

            // Gear corners (⚙ in tl/tr/bl/br)
            VStack {
                HStack { gear; Spacer(); gear }
                Spacer()
                HStack { gear; Spacer(); gear }
            }
            .padding(20)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Text("Chronicler")
                    .font(Theme.display(40))
                    .foregroundStyle(Theme.brassGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .glowVerdigris()
                Text("Your Audiobook Library")
                    .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim)
                    .padding(.top, 4)
                Text("⚙ ───────── ⚙")
                    .font(Theme.serif(14)).foregroundColor(Theme.borderBrass)
                    .padding(.top, 10)

                Spacer().frame(height: 40)

                NavigationLink(value: Route.archive) {
                    VStack(spacing: 6) {
                        Image("logo").resizable().scaledToFit().frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .glowVerdigris()
                        Text("Enter the Archive")
                            .font(Theme.serif(20)).foregroundColor(Theme.brassPale)
                            .glowVerdigris()
                        Text("Browse your collection")
                            .font(Theme.body(13)).foregroundColor(Theme.parchmentDim)
                    }
                    .padding(28)
                    .electricPanel(bg: Theme.surface, corner: 6, alpha: 0.8, glowRadius: 20)
                }

                Spacer()
                Spacer()
            }
            .padding()

            VStack {
                HStack {
                    Spacer()
                    Button("Sign Out") { auth.clear() }
                        .font(Theme.body(11)).foregroundColor(Theme.parchmentDim).opacity(0.5)
                }
                Spacer()
                UpdateBanner(api: auth.api).padding(.bottom, 12)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { StartupSound.shared.play() }
    }

    private var gear: some View {
        Text("⚙").font(.system(size: 26)).foregroundColor(Theme.border).opacity(0.6)
    }
}

// Status bar (connection dot + app version), ported from the Android UpdateBanner.
// iOS can't self-install APKs, so we never show the "tap to install" prompt — just
// the dot + version + Connected / Server unreachable. Shared by landing + archive.
struct UpdateBanner: View {
    let api: APIClient
    @State private var connected = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("●").font(.system(size: 10))
                .foregroundColor(connected ? Theme.verdigris : Theme.rust)
            Text("v\(version)").font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
            Text(connected ? "Connected" : "Server unreachable")
                .font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
        }
        .task {
            while !Task.isCancelled {
                connected = (await api.getLatestVersion()) != nil
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
}
