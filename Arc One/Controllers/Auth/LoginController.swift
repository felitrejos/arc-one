//
//  ViewController.swift
//  Arc One
//
//  Created by Felipe Trejos on 28/10/25.
//

import UIKit

class LoginController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var passwordPrompt: UITextField!
    @IBOutlet weak var emailPrompt: UITextField!
    @IBOutlet weak var appleLogin: UIButton!
    
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
}
