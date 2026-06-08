import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var mode = "login"
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Chronicler")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.brassGradient)
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

                field("Email", text: $email, secure: false)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                field("Password", text: $password, secure: true)

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
            }
            .padding(24)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(28)
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
        error = nil; busy = true
        Task {
            let token = mode == "login"
                ? await auth.api.login(email: email, password: password)
                : await auth.api.register(email: email, password: password)
            busy = false
            guard let token else {
                error = mode == "login" ? "Invalid email or password." : "Registration failed."
                return
            }
            auth.setToken(token, email: email)
        }
    }
}
