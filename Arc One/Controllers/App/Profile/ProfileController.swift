//
//  ProfileController.swift
//  Arc One
//
//  Created by Felipe Trejos on 29/11/25.
//

import UIKit
import FirebaseAuth
import GoogleSignIn

final class ProfileController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private var profileName: String? = nil
    private var profileEmail: String? = nil
    private var profileAvatar: UIImage? = nil

    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"

        tableView.dataSource = self
        tableView.delegate = self

        tableView.register(
            UINib(nibName: "ProfileSummaryCell", bundle: nil),
            forCellReuseIdentifier: "ProfileSummaryCell"
        )

        updateProfileFromFirebaseUser()

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            self?.refreshUserFromServerAndUpdateUI()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refreshUserFromServerAndUpdateUI()
    }

    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func refreshUserFromServerAndUpdateUI() {
        guard let user = Auth.auth().currentUser else {
            updateProfileFromFirebaseUser()
            return
        }

        user.reload { [weak self] error in
            DispatchQueue.main.async {
                if let _ = error { /* ignore silently */ }
                self?.updateProfileFromFirebaseUser()
            }
        }
    }

    private func updateProfileFromFirebaseUser() {
        guard let user = Auth.auth().currentUser else {
            profileName = ""
            profileEmail = ""
            profileAvatar = UIImage(systemName: "person.crop.circle.fill")
            reloadProfileSummaryRow()
            return
        }

        profileName = user.displayName ?? ""
        profileEmail = user.email ?? ""

        if let url = user.photoURL {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self else { return }
                let avatar = data.flatMap(UIImage.init(data:)) ?? UIImage(systemName: "person.crop.circle.fill")
                DispatchQueue.main.async {
                    self.profileAvatar = avatar
                    self.reloadProfileSummaryRow()
                }
            }.resume()
        } else {
            profileAvatar = UIImage(systemName: "person.crop.circle.fill")
            reloadProfileSummaryRow()
        }
    }

    private func reloadProfileSummaryRow() {
        let indexPath = IndexPath(row: 0, section: ProfileSection.profile.rawValue)
        if tableView.numberOfSections > indexPath.section,
           tableView.numberOfRows(inSection: indexPath.section) > indexPath.row {
            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            tableView.reloadData()
        }
    }

    private func goToPersonalInfo() {
        performSegue(withIdentifier: "showPersonalInfo", sender: self)
    }

    private func goToSettings() {
        performSegue(withIdentifier: "showSettings", sender: self)
    }

    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        didTapLogout()
    }

    @objc private func didTapLogout() {
        let alert = UIAlertController(
            title: "Log out?",
            message: "Are you sure you want to log out?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log out", style: .destructive, handler: { [weak self] _ in
            self?.performLogout()
        }))

        present(alert, animated: true)
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

    private func performLogout() {
        GIDSignIn.sharedInstance.signOut()

        do {
            try Auth.auth().signOut()
        } catch {
            let err = UIAlertController(
                title: "Logout failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            err.addAction(UIAlertAction(title: "OK", style: .default))
            present(err, animated: true)
            return
        }

        showLoginScreen()
    }
}

extension ProfileController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        ProfileSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = ProfileSection(rawValue: section) else { return 0 }
        return section.rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ProfileSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = ProfileSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        let row = section.rows[indexPath.row]

        if row == .profileSummary {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "ProfileSummaryCell",
                for: indexPath
            ) as! ProfileSummaryCell

            cell.selectionStyle = .none
            cell.configure(
                name: profileName ?? "",
                email: profileEmail ?? "",
                avatar: profileAvatar ?? UIImage(systemName: "person.crop.circle.fill")!
            )
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath)
        cell.textLabel?.text = row.title
        cell.accessoryType = row.accessory
        cell.textLabel?.textColor = row.isDestructive ? .systemRed : .label
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = ProfileSection(rawValue: indexPath.section) else { return }
        let row = section.rows[indexPath.row]

        if row == .profileSummary { return }

        switch row {
        case .personalInfo:
            goToPersonalInfo()
        case .settings:
            goToSettings()
        case .logout:
            didTapLogout()
        case .profileSummary:
            break
        }
    }
}
