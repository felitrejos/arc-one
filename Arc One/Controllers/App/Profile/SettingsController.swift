//
//  SettingsController.swift
//  Arc One
//
//  Created by Felipe Trejos on 13/12/25.
//

import UIKit
import SafariServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

final class SettingsController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private var provider: AuthProvider { .current() }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Settings"

        tableView.dataSource = self
        tableView.delegate = self

        if tableView.dequeueReusableCell(withIdentifier: "settingsCell") == nil {
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "settingsCell")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    private func rows(in sectionIndex: Int) -> [SettingsRow] {
        guard let section = SettingsSection(rawValue: sectionIndex) else { return [] }
        return section.rows(for: provider)
    }

    private func openURLInSafari(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    private func showOKAlert(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showError(_ error: Error, fallbackTitle: String = "Error") {
        showOKAlert(title: fallbackTitle, message: error.localizedDescription)
    }

    private func isRequiresRecentLogin(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == AuthErrorDomain else { return false }
        return ns.code == AuthErrorCode.requiresRecentLogin.rawValue
    }

    private func performWithReauthIfNeeded(_ operation: @escaping (@escaping (Error?) -> Void) -> Void) {
        operation { [weak self] error in
            guard let self else { return }

            if let error, self.isRequiresRecentLogin(error) {
                self.reauthenticateCurrentUser { [weak self] reauthError in
                    guard let self else { return }

                    if let reauthError {
                        self.showError(reauthError, fallbackTitle: "Re-authentication Failed")
                        return
                    }

                    operation { [weak self] retryError in
                        guard let self else { return }
                        if let retryError {
                            self.showError(retryError)
                        }
                    }
                }
            } else if let error {
                self.showError(error)
            }
        }
    }

    private func reauthenticateCurrentUser(completion: @escaping (Error?) -> Void) {
        switch provider {
        case .password:
            reauthenticateWithPassword(completion: completion)
        case .google:
            reauthenticateWithGoogle(completion: completion)
        }
    }

    private func reauthenticateWithPassword(completion: @escaping (Error?) -> Void) {
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
            if pwd.isEmpty {
                completion(NSError(domain: "App", code: -3, userInfo: [NSLocalizedDescriptionKey: "Password cannot be empty."]))
                return
            }

            let credential = EmailAuthProvider.credential(withEmail: email, password: pwd)
            user.reauthenticate(with: credential) { _, error in
                DispatchQueue.main.async { completion(error) }
            }
        })

        present(alert, animated: true)
    }

    private func reauthenticateWithGoogle(completion: @escaping (Error?) -> Void) {
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

        GIDSignIn.sharedInstance.signIn(withPresenting: self) { signInResult, error in
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

    private func showLoginScreen() {
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
            present(loginVC, animated: true)
        }
    }

    private func editProfileInline() {
        guard let user = Auth.auth().currentUser else { return }

        let alert = UIAlertController(title: "Edit Profile", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Name"
            tf.autocapitalizationType = .words
            tf.text = user.displayName
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }

            let newName = (alert.textFields?.first?.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !newName.isEmpty else {
                self.showOKAlert(title: "Error", message: "Name cannot be empty.")
                return
            }

            self.performWithReauthIfNeeded { done in
                guard let user = Auth.auth().currentUser else {
                    done(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session."]))
                    return
                }

                let change = user.createProfileChangeRequest()
                change.displayName = newName

                change.commitChanges { error in
                    if let error {
                        done(error)
                        return
                    }
                    user.reload { reloadError in
                        done(reloadError)
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.tableView.reloadData()
            }
        })

        present(alert, animated: true)
    }

    private func changePassword() {
        guard let _ = Auth.auth().currentUser else { return }

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
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }

            let p1 = alert.textFields?.first?.text ?? ""
            let p2 = alert.textFields?.last?.text ?? ""

            guard !p1.isEmpty, p1 == p2 else {
                self.showOKAlert(title: "Error", message: "Passwords do not match.")
                return
            }

            self.performWithReauthIfNeeded { done in
                guard let user = Auth.auth().currentUser else {
                    done(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session."]))
                    return
                }

                user.updatePassword(to: p1) { error in
                    done(error)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.showOKAlert(title: "Updated", message: "Your password was updated.")
            }
        })

        present(alert, animated: true)
    }

    private func confirmDeleteAccount() {
        let alert = UIAlertController(
            title: "Delete Account",
            message: "This action cannot be undone. Are you sure you want to permanently delete your account?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteAccount()
        })

        present(alert, animated: true)
    }

    private func performDeleteAccount() {
        performWithReauthIfNeeded { [weak self] done in
            guard let self else { return }
            guard let user = Auth.auth().currentUser else {
                done(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user session."]))
                return
            }

            user.delete { error in
                if let error {
                    done(error)
                    return
                }

                do { try Auth.auth().signOut() } catch { /* ignore */ }

                DispatchQueue.main.async { [weak self] in
                    self?.showLoginScreen()
                }

                done(nil)
            }
        }
    }
}

extension SettingsController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows(in: section).count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        SettingsSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)

        let row = rows(in: indexPath.section)[indexPath.row]
        cell.textLabel?.text = row.title
        cell.accessoryType = row.accessory
        cell.textLabel?.textColor = row.isDestructive ? .systemRed : .label
        cell.selectionStyle = .default

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = rows(in: indexPath.section)[indexPath.row]

        switch row {
        case .editProfile:
            editProfileInline()

        case .changePassword:
            changePassword()

        case .deleteAccount:
            confirmDeleteAccount()

        case .terms:
            openURLInSafari("https://policies.google.com/terms")

        case .privacy:
            openURLInSafari("https://policies.google.com/privacy")
        }
    }
}
