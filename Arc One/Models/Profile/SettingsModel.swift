//
//  SettingsModel.swift
//  Arc One
//
//  Created by Felipe Trejos on 14/12/25.
//

import UIKit
import FirebaseAuth

enum SettingsSection: Int, CaseIterable {
    case account
    case legal

    var title: String? {
        switch self {
        case .account: return "Account"
        case .legal: return "Legal"
        }
    }

    func rows(for provider: AuthProvider) -> [SettingsRow] {
        switch self {
        case .account:
            switch provider {
            case .google:
                return [.editProfile, .deleteAccount]
            case .password:
                return [.editProfile, .changePassword, .deleteAccount]
            }
        case .legal:
            return [.terms, .privacy]
        }
    }
}

enum SettingsRow {
    case editProfile
    case changePassword
    case deleteAccount
    case terms
    case privacy

    var title: String {
        switch self {
        case .editProfile: return "Edit Profile"
        case .changePassword: return "Change Password"
        case .deleteAccount: return "Delete Account"
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        }
    }

    var accessory: UITableViewCell.AccessoryType {
        switch self {
        case .deleteAccount:
            return .none
        default:
            return .disclosureIndicator
        }
    }

    var isDestructive: Bool {
        self == .deleteAccount
    }
}

enum AuthProvider {
    case google
    case password

    static func current() -> AuthProvider {
        let providers = Auth.auth().currentUser?.providerData.map { $0.providerID } ?? []

        if providers.contains("google.com") { return .google }
        return .password
    }
}
