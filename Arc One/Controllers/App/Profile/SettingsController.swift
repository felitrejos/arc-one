//
//  SettingsController.swift
//  Arc One
//
//  Created by Felipe Trejos on 13/12/25.
//

import UIKit
import SafariServices
import FirebaseAuth

final class SettingsController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private let provider: AuthProvider = .current()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Settings"

        tableView.dataSource = self
        tableView.delegate = self


        if tableView.dequeueReusableCell(withIdentifier: "settingsCell") == nil {
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "settingsCell")
        }
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

    private func editProfileInline() {
        guard let user = Auth.auth().currentUser else { return }

        let alert = UIAlertController(title: "Edit Profile", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Name"
            tf.autocapitalizationType = .words
            tf.text = user.displayName
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let newName = alert.textFields?.first?.text ?? ""
            let change = user.createProfileChangeRequest()
            change.displayName = newName
            change.commitChanges { [weak self] error in
                DispatchQueue.main.async {
                    if let error {
                        let err = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        err.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(err, animated: true)
                    } else {
                        self?.tableView.reloadData()
                    }
                }
            }
        })

        present(alert, animated: true)
    }

    private func changeEmail() {
        guard let user = Auth.auth().currentUser else { return }

        let alert = UIAlertController(title: "Change Email", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "New email"
            tf.keyboardType = .emailAddress
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            let newEmail = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !newEmail.isEmpty else { return }

            user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                DispatchQueue.main.async {
                    if let error {
                        let err = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        err.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(err, animated: true)
                    } else {
                        let ok = UIAlertController(
                            title: "Verify Email",
                            message: "We sent a verification email to your new address. Open it to confirm the change.",
                            preferredStyle: .alert
                        )
                        ok.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(ok, animated: true)
                    }
                }
            }
        })

        present(alert, animated: true)
    }

    private func changePassword() {
        guard let user = Auth.auth().currentUser else { return }

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
            let p1 = alert.textFields?.first?.text ?? ""
            let p2 = alert.textFields?.last?.text ?? ""
            guard !p1.isEmpty, p1 == p2 else {
                let err = UIAlertController(title: "Error", message: "Passwords do not match.", preferredStyle: .alert)
                err.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(err, animated: true)
                return
            }

            user.updatePassword(to: p1) { error in
                DispatchQueue.main.async {
                    if let error {
                        let err = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        err.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(err, animated: true)
                    } else {
                        let ok = UIAlertController(title: "Updated", message: "Your password was updated.", preferredStyle: .alert)
                        ok.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(ok, animated: true)
                    }
                }
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
        guard let user = Auth.auth().currentUser else { return }

        user.delete { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    let message = error.localizedDescription
                    let alert = UIAlertController(title: "Couldn't Delete Account", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    return
                }

                let alert = UIAlertController(title: "Account Deleted", message: "Your account has been deleted.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginController")
                    loginVC.modalPresentationStyle = .fullScreen
                    self?.present(loginVC, animated: true)
                })
                self?.present(alert, animated: true)
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

        case .changeEmail:
            changeEmail()

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
