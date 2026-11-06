import AuthenticationServices
import UIKit

// Saves and offers the Chronicler login through the Passwords app, explicitly. Tagging the
// fields alone (textContentType) never produced a "Save password?" prompt on device, so we
// ask iOS directly — the same shape as Android's Credential Manager. Both calls rely on the
// webcredentials entitlement + the server's apple-app-site-association file.
final class PasswordKeeper: NSObject, ASAuthorizationControllerDelegate,
                            ASAuthorizationControllerPresentationContextProviding {
    static let domain = "chronicler.mckeeth.app"

    private var continuation: CheckedContinuation<ASPasswordCredential?, Never>?
    private var controller: ASAuthorizationController?

    /// Shows iOS's "Save password?" prompt. Declining is fine; nothing to do either way.
    static func save(email: String, password: String) {
        SecAddSharedWebCredential(domain as CFString, email as CFString, password as CFString) { _ in }
    }

    /// Offers a saved Chronicler login in the system sheet. Nil when none is saved or the
    /// user dismisses it.
    func savedLogin() async -> ASPasswordCredential? {
        await withCheckedContinuation { cont in
            continuation = cont
            let c = ASAuthorizationController(
                authorizationRequests: [ASAuthorizationPasswordProvider().createRequest()])
            c.delegate = self
            c.presentationContextProvider = self
            controller = c
            c.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        finish(authorization.credential as? ASPasswordCredential)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        finish(nil)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }

    private func finish(_ credential: ASPasswordCredential?) {
        continuation?.resume(returning: credential)
        continuation = nil
        controller = nil
    }
}
