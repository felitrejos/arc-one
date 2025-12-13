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
    private var originalGoogleButtonTitle: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        originalGoogleButtonTitle = googleLogin.title(for: .normal)
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
        performSegue(withIdentifier: "loginToHome", sender: self)
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

                self.performSegue(withIdentifier: "loginToHome", sender: self)
            }
        }
    }

    private func setGoogleLoading(_ isLoading: Bool) {
        DispatchQueue.main.async {
            self.googleLogin.isEnabled = !isLoading
            self.googleLogin.alpha = isLoading ? 0.7 : 1.0

            if isLoading {
                self.originalGoogleButtonTitle = self.originalGoogleButtonTitle ?? self.googleLogin.title(for: .normal)
                self.googleLogin.setTitle("Signing in…", for: .normal)

                // Lightweight spinner inside the button
                let spinnerTag = 9991
                if self.googleLogin.viewWithTag(spinnerTag) == nil {
                    let spinner = UIActivityIndicatorView(style: .medium)
                    spinner.tag = spinnerTag
                    spinner.translatesAutoresizingMaskIntoConstraints = false
                    self.googleLogin.addSubview(spinner)
                    NSLayoutConstraint.activate([
                        spinner.centerYAnchor.constraint(equalTo: self.googleLogin.centerYAnchor),
                        spinner.trailingAnchor.constraint(equalTo: self.googleLogin.trailingAnchor, constant: -16)
                    ])
                    spinner.startAnimating()
                }
            } else {
                self.googleLogin.setTitle(self.originalGoogleButtonTitle ?? "Continue with Google", for: .normal)
                if let spinner = self.googleLogin.viewWithTag(9991) as? UIActivityIndicatorView {
                    spinner.stopAnimating()
                    spinner.removeFromSuperview()
                }
            }
        }
    }

    private func showAuthAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}
