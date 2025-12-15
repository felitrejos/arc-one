//
//  ViewController.swift
//  Arc One
//
//  Created by Felipe Trejos on 28/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

class LoginController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var passwordPrompt: UITextField!
    @IBOutlet weak var emailPrompt: UITextField!
    @IBOutlet weak var googleLogin: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTextFields()
        setupTapToDismissKeyboard()
    }
    
    private func setupTextFields() {
        emailPrompt.delegate = self
        passwordPrompt.delegate = self
        
        [emailPrompt, passwordPrompt].forEach { textField in
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

    private func setButtonLoading(_ button: UIButton, isLoading: Bool) {
        DispatchQueue.main.async {
            button.isEnabled = !isLoading

            if isLoading {
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
        performSegue(withIdentifier: "loginToSignup", sender: self)
    }
    
    @IBAction func loginTapped(_ sender: UIButton) {
        dismissKeyboard()

        let email = (emailPrompt.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordPrompt.text ?? ""

        guard !email.isEmpty else {
            showAuthAlert(title: "Missing email", message: "Please enter your email address.")
            return
        }

        guard !password.isEmpty else {
            showAuthAlert(title: "Missing password", message: "Please enter your password.")
            return
        }

        setButtonLoading(sender, isLoading: true)

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let self = self else { return }
            self.setButtonLoading(sender, isLoading: false)

            if let error = error {
                self.showAuthAlert(title: "Login failed", message: error.localizedDescription)
                return
            }

            guard let user = Auth.auth().currentUser else {
                self.showAuthAlert(title: "Login failed", message: "Could not read signed-in user.")
                return
            }

            guard user.isEmailVerified else {
                self.showAuthAlert(
                    title: "Email not verified",
                    message: "Please verify your email first. Check your inbox (and spam), then log in again."
                )
                try? Auth.auth().signOut()
                return
            }

            self.performSegue(withIdentifier: "loginToHome", sender: self)
        }
    }

    @IBAction func googleLoginTapped(_ sender: UIButton) {
        signInWithGoogle()
    }

    private func signInWithGoogle() {
        setGoogleLoading(true)

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            setGoogleLoading(false)
            showAuthAlert(title: "Config error", message: "Missing Firebase clientID. Verify FirebaseApp.configure() and GoogleService-Info.plist.")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // iOS 15+ API
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.setGoogleLoading(false)
                self.showAuthAlert(title: "Google Sign-In failed", message: error.localizedDescription)
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                self.setGoogleLoading(false)
                self.showAuthAlert(title: "Google Sign-In failed", message: "Could not fetch Google ID token.")
                return
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            Auth.auth().signIn(with: credential) { [weak self] _, error in
                guard let self = self else { return }
                self.setGoogleLoading(false)

                if let error = error {
                    self.showAuthAlert(title: "Firebase login failed", message: error.localizedDescription)
                    return
                }

                guard let user = Auth.auth().currentUser else {
                    self.showAuthAlert(title: "Login failed", message: "Could not read signed-in user.")
                    return
                }

                guard user.isEmailVerified else {
                    self.showAuthAlert(
                        title: "Email not verified",
                        message: "Please verify your email first, then try again."
                    )
                    try? Auth.auth().signOut()
                    return
                }

                self.performSegue(withIdentifier: "loginToHome", sender: self)
            }
        }
    }

    private func setGoogleLoading(_ isLoading: Bool) {
        setButtonLoading(googleLogin, isLoading: isLoading)
    }

    private func showAuthAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}
