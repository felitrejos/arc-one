//
//  SettingsService.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import UIKit
import SafariServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

final class SettingsService {

    // Public

    func openURL(_ urlString: String, from vc: UIViewController) {
        guard let url = URL(string: urlString) else { return }
        let safari = SFSafariViewController(url: url)
        vc.present(safari, animated: true)
    }

    func editProfileInline(from vc: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else { return }

        let alert = UIAlertController(title: "Edit Profile", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Name"
            tf.autocapitalizationType = .words
            tf.text = user.displayName
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let newName = (alert.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else {
                completion(.failure(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty."])))
                return
            }

            self.performWithReauthIfNeeded(from: vc) { done in
                guard let user = Auth.auth().currentUser else {
                    done(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session."]))
                    return
                }

                let change = user.createProfileChangeRequest()
                change.displayName = newName
                change.commitChanges { error in
                    if let error { done(error); return }
                    user.reload { reloadError in
                        done(reloadError)
                    }
                }
            } completion: { result in
                completion(result.map { _ in () })
            }
        })

        vc.present(alert, animated: true)
    }

    func changePassword(from vc: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        guard Auth.auth().currentUser != nil else { return }

        let alert = UIAlertController(title: "Change Password", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "New password"
            tf.isSecureTextEntry = true
            tf.textContentType = .newPassword
        }
        alert.addTextField { tf in
            tf.placeholder = "Confirm new password"
            tf.isSecureTextEntry = true
            tf.textContentType = .newPassword
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let p1 = alert.textFields?.first?.text ?? ""
            let p2 = alert.textFields?.last?.text ?? ""
            guard !p1.isEmpty, p1 == p2 else {
                completion(.failure(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "Passwords do not match."])))
                return
            }

            self.performWithReauthIfNeeded(from: vc) { done in
                guard let user = Auth.auth().currentUser else {
                    done(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session."]))
                    return
                }
                user.updatePassword(to: p1) { error in
                    done(error)
                }
            } completion: { result in
                completion(result.map { _ in () })
            }
        })

        vc.present(alert, animated: true)
    }

    func confirmDeleteAccount(from vc: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        let alert = UIAlertController(
            title: "Delete Account",
            message: "This action cannot be undone. Are you sure you want to permanently delete your account?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteAccount(from: vc, completion: completion)
        })

        vc.present(alert, animated: true)
    }

    func logoutAndShowLogin(from vc: UIViewController) {
        GIDSignIn.sharedInstance.signOut()
        do { try Auth.auth().signOut() } catch { /* ignore */ }
        showLoginScreen(from: vc)
    }

    func showLoginScreen(from vc: UIViewController) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginController")
        loginVC.modalPresentationStyle = .fullScreen

        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first

        if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) {
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
                window.rootViewController = loginVC
                window.makeKeyAndVisible()
            })
        } else {
            vc.present(loginVC, animated: true)
        }
    }

    // Delete account

    private func deleteAccount(from vc: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        performWithReauthIfNeeded(from: vc) { done in
            guard let user = Auth.auth().currentUser else {
                done(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session."]))
                return
            }

            user.delete { error in
                if let error { done(error); return }
                do { try Auth.auth().signOut() } catch { /* ignore */ }
                done(nil)
            }
        } completion: { result in
            completion(result.map { _ in () })
        }
    }

    // Reauth core

    private func isRequiresRecentLogin(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == AuthErrorDomain else { return false }
        return ns.code == AuthErrorCode.requiresRecentLogin.rawValue
    }

    private func performWithReauthIfNeeded(
        from vc: UIViewController,
        operation: @escaping (@escaping (Error?) -> Void) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        operation { error in
            if let error, self.isRequiresRecentLogin(error) {
                self.reauthenticateCurrentUser(from: vc) { reauthError in
                    if let reauthError {
                        completion(.failure(reauthError))
                        return
                    }
                    operation { retryError in
                        if let retryError { completion(.failure(retryError)) }
                        else { completion(.success(())) }
                    }
                }
            } else if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    private func reauthenticateCurrentUser(from vc: UIViewController, completion: @escaping (Error?) -> Void) {
        switch AuthProvider.current() {
        case .password:
            reauthenticateWithPassword(from: vc, completion: completion)
        case .google:
            reauthenticateWithGoogle(from: vc, completion: completion)
        }
    }

    private func reauthenticateWithPassword(from vc: UIViewController, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session."]))
            return
        }
        guard let email = user.email, !email.isEmpty else {
            completion(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "User has no email."]))
            return
        }

        let alert = UIAlertController(
            title: "Confirm Password",
            message: "For security, please enter your current password.",
            preferredStyle: .alert
        )

        alert.addTextField { tf in
            tf.placeholder = "Current password"
            tf.isSecureTextEntry = true
            tf.textContentType = .password
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(NSError(domain: "App", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cancelled."]))
        })

        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            let pwd = alert.textFields?.first?.text ?? ""
            guard !pwd.isEmpty else {
                completion(NSError(domain: "App", code: -3, userInfo: [NSLocalizedDescriptionKey: "Password cannot be empty."]))
                return
            }

            let credential = EmailAuthProvider.credential(withEmail: email, password: pwd)
            user.reauthenticate(with: credential) { _, error in
                DispatchQueue.main.async { completion(error) }
            }
        })

        vc.present(alert, animated: true)
    }

    private func reauthenticateWithGoogle(from vc: UIViewController, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session."]))
            return
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing Firebase clientID."]))
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: vc) { signInResult, error in
            if let error {
                DispatchQueue.main.async { completion(error) }
                return
            }

            guard
                let signInResult,
                let idToken = signInResult.user.idToken?.tokenString
            else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google token missing."]))
                }
                return
            }

            let accessToken = signInResult.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            user.reauthenticate(with: credential) { _, error in
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
}
