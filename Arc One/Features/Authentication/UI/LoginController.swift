import UIKit

final class LoginController: UIViewController, UITextFieldDelegate {

    @IBOutlet private weak var passwordPrompt: UITextField!
    @IBOutlet private weak var emailPrompt: UITextField!
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
        [emailPrompt, passwordPrompt].forEach { $0?.applyAuthStyle() }
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
        performSegue(withIdentifier: "loginToSignup", sender: self)
    }

    @IBAction private func loginTapped(_ sender: UIButton) {
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

        Task { [weak self] in
            guard let self else { return }
            do {
                try await authService.login(email: email, password: password)
                await MainActor.run {
                    self.setButtonLoading(sender, isLoading: false)
                    self.offerToEnableFaceIDIfNeeded {
                        self.performSegue(withIdentifier: "loginToHome", sender: self)
                    }
                }
            } catch {
                await MainActor.run {
                    self.setButtonLoading(sender, isLoading: false)
                    self.showAuthAlert(title: "Login failed", message: error.localizedDescription)
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
                        self.performSegue(withIdentifier: "loginToHome", sender: self)
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

    private func setButtonLoading(_ button: UIButton, isLoading: Bool) {
        DispatchQueue.main.async {
            button.isEnabled = !isLoading
            button.alpha = isLoading ? 0.75 : 1.0
            button.transform = isLoading ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }

    private func showAuthAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
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
