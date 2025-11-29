//
//  UITextField.swift
//  Arc One
//
//  Created by Felipe Trejos on 29/11/25.
//

import UIKit

extension UITextField {
    
    func applyAuthStyle() {
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.lightGray.cgColor
        self.backgroundColor = .white
        
        if self.leftView == nil {
            self.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
            self.leftViewMode = .always
        }
    }
    
    func setFocusedBorder() {
        self.layer.borderColor = UIColor.black.cgColor
    }
    
    func setUnfocusedBorder() {
        self.layer.borderColor = UIColor.lightGray.cgColor
    }
}
