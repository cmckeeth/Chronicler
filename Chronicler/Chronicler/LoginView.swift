import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var mode = "login"
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var showOffline = false
    @State private var hasDownloads = false
    @State private var keeper = PasswordKeeper()

    var body: some View {
        ZStack {
            ThemedBackground(intensity: 1.2)
            VStack(spacing: 16) {
                Text("Chronicler")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.brassGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .glowVerdigris()
                Text("Your audiobook library")
                    .font(Theme.serif(14)).foregroundColor(Theme.parchmentDim)

                HStack(spacing: 0) {
                    tab("Sign In", "login")
                    tab("Register", "register")
                }
                .padding(4)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Content types let the Passwords app fill these in and offer to save after
                // sign-in (paired with the webcredentials entitlement + the server's AASA file).
                field("Email", text: $email, secure: false)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                field("Password", text: $password, secure: true)
                    .textContentType(mode == "login" ? .password : .newPassword)

                if let error {
                    Text(error).font(Theme.body(13)).foregroundColor(Theme.rust)
                }

                Button(action: submit) {
                    Text(mode == "login" ? "Sign In" : "Create Account")
                        .font(Theme.serif(16)).foregroundColor(Theme.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.brassGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .disabled(busy)

                // Signing in needs the server; downloaded books don't.
                if hasDownloads {
                    Button { showOffline = true } label: {
                        LocalDownloadsButton(serverDown: false)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(24)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(28)
        }
        .onAppear { hasDownloads = Downloads.hasAny() }
        .task { await offerSavedLogin() }
        .fullScreenCover(isPresented: $showOffline) {
            OfflineLibrarySheet(onClose: { showOffline = false })
                .environmentObject(auth)
        }
    }

    private func tab(_ label: String, _ value: String) -> some View {
        Button { mode = value } label: {
            Text(label).font(Theme.serif(14))
                .foregroundColor(mode == value ? Theme.ink : Theme.parchmentMid)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(mode == value ? Theme.brass : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure { SecureField(placeholder, text: text) }
            else { TextField(placeholder, text: text) }
        }
        .font(Theme.body(15)).foregroundColor(Theme.parchment)
        .padding(10)
        .background(Theme.surface2)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border, lineWidth: 1))
    }

    private func submit() {
        Task { await signIn(email: email, password: password, offerSave: true) }
    }

    // offerSave: false when the login came from the Passwords app, so we don't ask to save
    // what it just gave us.
    private func signIn(email: String, password: String, offerSave: Bool) async {
        error = nil; busy = true
        let token = mode == "login"
            ? await auth.api.login(email: email, password: password)
            : await auth.api.register(email: email, password: password)
        busy = false
        guard let token else {
            error = mode == "login" ? "Invalid email or password." : "Registration failed."
            return
        }
        if offerSave { PasswordKeeper.save(email: email, password: password) }
        auth.setToken(token, email: email)
    }

    // Offer a saved Chronicler login as soon as the screen opens; picking one signs in.
    private func offerSavedLogin() async {
        guard let saved = await keeper.savedLogin() else { return }
        email = saved.user; password = saved.password
        await signIn(email: saved.user, password: saved.password, offerSave: false)
    }
}
