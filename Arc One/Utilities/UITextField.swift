import UIKit

extension UITextField {
    
    func applyAuthStyle() {
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
        self.layer.borderWidth = 1
        self.layer.borderColor = UIColor.systemGray5.cgColor
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
        self.layer.borderColor = UIColor.systemGray5.cgColor
    }

    func applyFintechStyle(themeColor: UIColor, isCurrency: Bool = false) {
        self.borderStyle = .none
        self.layer.cornerRadius = 10
        self.layer.borderWidth = 1.2
        self.layer.borderColor = UIColor.systemGray5.cgColor
        self.backgroundColor = .white
        self.tintColor = themeColor
        self.keyboardType = .decimalPad
        self.returnKeyType = .done
        
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: self.frame.height))
        self.rightView = rightPaddingView
        self.rightViewMode = .always
        
        if isCurrency {
            let label = UILabel()
            label.text = "  $ " 
            label.textColor = .systemGray
            label.font = .systemFont(ofSize: 16, weight: .bold)
            label.sizeToFit()
            self.leftView = label
        } else {
            self.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 0))
        }
        self.leftViewMode = .always
    }
    
    func setFocusedThemeBorder(color: UIColor) {
        UIView.animate(withDuration: 0.2) {
            self.layer.borderColor = color.cgColor
            self.layer.borderWidth = 2.0
        }
    }
}
