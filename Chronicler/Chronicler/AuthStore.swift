import Foundation
import Combine

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var email: String?

    // Persisted: auto-play the next chapter when one finishes (default off).
    @Published private(set) var autoplayNext: Bool
    // Persisted: boost playback volume beyond 100% (default off).
    @Published private(set) var volumeBoosted: Bool

    let api = APIClient()

    private let tokenKey = "chronicler.token"
    private let emailKey = "chronicler.email"
    private let autoplayKey = "chronicler.autoplay"
    private let volumeBoostKey = "chronicler.volumeBoost"

    init() {
        autoplayNext = UserDefaults.standard.bool(forKey: autoplayKey)
        volumeBoosted = UserDefaults.standard.bool(forKey: volumeBoostKey)
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            api.token = token
            email = UserDefaults.standard.string(forKey: emailKey)
            isAuthenticated = true
        }
    }

    func setAutoplay(_ v: Bool) {
        autoplayNext = v
        UserDefaults.standard.set(v, forKey: autoplayKey)
    }

    func setVolumeBoost(_ v: Bool) {
        volumeBoosted = v
        UserDefaults.standard.set(v, forKey: volumeBoostKey)
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
