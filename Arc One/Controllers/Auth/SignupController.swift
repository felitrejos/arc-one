//
//  SignupController.swift
//  Arc One
//
//  Created by Felipe Trejos on 29/11/25.
//

import UIKit
import FirebaseAuth

class SignupController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailPrompt: UITextField!
    @IBOutlet weak var passwordPrompt: UITextField!
    @IBOutlet weak var confirmPasswordPrompt: UITextField!
    @IBOutlet weak var googleLogin: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        setupTapToDismissKeyboard()
    }
    
    private func setupTextFields() {
        emailPrompt.delegate = self
        passwordPrompt.delegate = self
        confirmPasswordPrompt.delegate = self
        
        [emailPrompt, passwordPrompt, confirmPasswordPrompt].forEach { textField in
            textField?.applyAuthStyle()
        }
    }
    
    private func setupTapToDismissKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func showAuthAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private func setButtonLoading(_ button: UIButton, isLoading: Bool) {
        DispatchQueue.main.async {
            button.isEnabled = !isLoading

            if isLoading {
                // “Pressed” feel while loading
                button.alpha = 0.75
                button.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            } else {
                button.alpha = 1.0
                button.transform = .identity
            }
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.setFocusedBorder()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.setUnfocusedBorder()
    }
    
    @IBAction func signupTapped(_ sender: UIButton) {
        dismissKeyboard()

        let email = (emailPrompt.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordPrompt.text ?? ""
        let confirmPassword = confirmPasswordPrompt.text ?? ""

        guard !email.isEmpty else {
            showAuthAlert(title: "Missing email", message: "Please enter your email address.")
            return
        }

        guard !password.isEmpty else {
            showAuthAlert(title: "Missing password", message: "Please enter a password.")
            return
        }

        guard password.count >= 6 else {
            showAuthAlert(title: "Weak password", message: "Your password must be at least 6 characters long.")
            return
        }

        guard password == confirmPassword else {
            showAuthAlert(title: "Passwords don't match", message: "Please make sure both passwords are the same.")
            return
        }

        setButtonLoading(sender, isLoading: true)

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            self.setButtonLoading(sender, isLoading: false)

            if let error = error {
                self.showAuthAlert(title: "Sign up failed", message: error.localizedDescription)
                return
            }

            guard let user = result?.user else {
                self.showAuthAlert(title: "Sign up failed", message: "Could not create user.")
                return
            }

            // Send email verification
            user.sendEmailVerification { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    self.showAuthAlert(
                        title: "Account created",
                        message: "Your account was created, but we couldn't send the verification email.\n\n\(error.localizedDescription)"
                    )
                    self.dismiss(animated: true)
                    return
                }

                let alert = UIAlertController(
                    title: "Verify your email",
                    message: "We’ve sent a verification link to \(user.email ?? "your email"). Please verify your email before continuing.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    self.dismiss(animated: true)
                })
                DispatchQueue.main.async {
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
