import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import LocalAuthentication

final class AuthService {

    private let auth: Auth
    private var biometricsStore: BiometricsStoring

    init(auth: Auth = FirebaseManager.auth, biometricsStore: BiometricsStoring = BiometricsStore()) {
        self.auth = auth
        self.biometricsStore = biometricsStore
    }

    // Email/Password Login
    func login(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        let user = result.user

        guard user.isEmailVerified else {
            try? auth.signOut()
            throw AuthError.emailNotVerified
        }
    }

    // Sign up
    func signup(email: String, password: String) async throws -> String {
        let result = try await auth.createUser(withEmail: email, password: password)
        let user = result.user
        try await user.sendEmailVerification()
        return user.email ?? email
    }

    // Google Sign-In
    func loginWithGoogle(presenting vc: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: vc)

        guard
            let idToken = result.user.idToken?.tokenString
        else {
            throw AuthError.missingUser
        }

        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        let authResult = try await auth.signIn(with: credential)
        let user = authResult.user

        guard user.isEmailVerified else {
            try? auth.signOut()
            throw AuthError.emailNotVerified
        }
    }

    // Biometrics prompt
    func shouldOfferBiometrics() -> Bool {
        if biometricsStore.biometricsEnabled { return false }

        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    func enableBiometrics() {
        biometricsStore.biometricsEnabled = true
    }
}
