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
                Text("Your Audiobook Library")
                    .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim)
                    .padding(.top, 4)
                Text("⚙ ───────── ⚙")
                    .font(Theme.serif(14)).foregroundColor(Theme.borderBrass)
                    .padding(.top, 10)

                Spacer().frame(height: 40)

                NavigationLink(value: Route.archive) {
                    VStack(spacing: 6) {
                        Image("logo").resizable().scaledToFit().frame(width: 90, height: 90)
                        Text("Enter the Archive")
                            .font(Theme.serif(20)).foregroundColor(Theme.brassPale)
                        Text("Browse your collection")
                            .font(Theme.body(13)).foregroundColor(Theme.parchmentDim)
                    }
                    .padding(24)
                    .background(Theme.surface.opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.borderBrass, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
