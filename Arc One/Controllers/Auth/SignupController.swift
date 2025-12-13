//
//  SignupController.swift
//  Arc One
//
//  Created by Felipe Trejos on 29/11/25.
//

import UIKit

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
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.setFocusedBorder()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.setUnfocusedBorder()
    }
    
    @IBAction func signupTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "signupToHome", sender: self)
    }
}
