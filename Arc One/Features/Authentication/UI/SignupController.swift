import UIKit

final class SignupController: UIViewController, UITextFieldDelegate {

    @IBOutlet private weak var emailPrompt: UITextField!
    @IBOutlet private weak var passwordPrompt: UITextField!
    @IBOutlet private weak var confirmPasswordPrompt: UITextField!
    @IBOutlet private weak var googleLogin: UIButton!

    private let authService = AuthService()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        setupTapToDismissKeyboard()
    }

    private func setupTextFields() {
        emailPrompt.delegate = self
        passwordPrompt.delegate = self
        confirmPasswordPrompt.delegate = self

        [emailPrompt, passwordPrompt, confirmPasswordPrompt].forEach { $0?.applyAuthStyle() }
    }

    private func setupTapToDismissKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    func textFieldDidBeginEditing(_ textField: UITextField) { textField.setFocusedBorder() }
    func textFieldDidEndEditing(_ textField: UITextField) { textField.setUnfocusedBorder() }

    @IBAction private func signupTapped(_ sender: UIButton) {
        dismissKeyboard()

        let email = (emailPrompt.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordPrompt.text ?? ""
        let confirm = confirmPasswordPrompt.text ?? ""

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

        guard password == confirm else {
            showAuthAlert(title: "Passwords don't match", message: "Please make sure both passwords are the same.")
            return
        }

        setButtonLoading(sender, isLoading: true)

        Task { [weak self] in
            guard let self else { return }
            do {
                let emailShown = try await authService.signup(email: email, password: password)

                await MainActor.run {
                    self.setButtonLoading(sender, isLoading: false)

                    let alert = UIAlertController(
                        title: "Verify your email",
                        message: "We've sent a verification link to \(emailShown). Please verify your email before continuing.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.dismiss(animated: true)
                    })
                    self.present(alert, animated: true)
                }

            } catch {
                await MainActor.run {
                    self.setButtonLoading(sender, isLoading: false)
                    self.showAuthAlert(title: "Sign up failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    @IBAction private func googleLoginTapped(_ sender: UIButton) {
        setButtonLoading(googleLogin, isLoading: true)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await authService.loginWithGoogle(presenting: self)
                await MainActor.run {
                    self.setButtonLoading(self.googleLogin, isLoading: false)
                    self.offerToEnableFaceIDIfNeeded {
                        self.performSegue(withIdentifier: "signupToHome", sender: self)
                    }
                }
            } catch {
                await MainActor.run {
                    self.setButtonLoading(self.googleLogin, isLoading: false)
                    self.showAuthAlert(title: "Google Sign-In failed", message: error.localizedDescription)
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

    private func setButtonLoading(_ button: UIButton, isLoading: Bool) {
        DispatchQueue.main.async {
            button.isEnabled = !isLoading
            button.alpha = isLoading ? 0.75 : 1.0
            button.transform = isLoading ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
    
    private func offerToEnableFaceIDIfNeeded(completion: @escaping () -> Void) {
        guard authService.shouldOfferBiometrics() else {
            completion()
            return
        }

        let alert = UIAlertController(
            title: "Enable Face ID?",
            message: "Use Face ID to unlock the app next time.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Not now", style: .cancel) { _ in completion() })
        alert.addAction(UIAlertAction(title: "Enable", style: .default) { [weak self] _ in
            self?.authService.enableBiometrics()
            completion()
        })

        present(alert, animated: true)
    }
}
