import Foundation
import Combine

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var email: String?

    let api = APIClient()

    private let tokenKey = "chronicler.token"
    private let emailKey = "chronicler.email"

    init() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            api.token = token
            email = UserDefaults.standard.string(forKey: emailKey)
            isAuthenticated = true
        }
    }

    func setToken(_ token: String, email: String) {
        api.token = token
        self.email = email
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(email, forKey: emailKey)
        isAuthenticated = true
    }

    func clear() {
        api.token = nil
        email = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        isAuthenticated = false
    }
}
