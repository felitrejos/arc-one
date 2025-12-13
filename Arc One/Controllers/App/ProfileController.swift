//
//  ProfileController.swift
//  Arc One
//
//  Created by Felipe Trejos on 29/11/25.
//

import UIKit
import FirebaseAuth
import GoogleSignIn

class ProfileController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Profile"
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

        if let nav = navigationController {
            nav.popToRootViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
