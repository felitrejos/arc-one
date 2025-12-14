//
//  ProfileMenuModel.swift
//  Arc One
//
//  Created by Felipe Trejos on 14/12/25.
//

import UIKit

enum ProfileSection: Int, CaseIterable {
    case profile
    case account
    case session

    var title: String? {
        switch self {
        case .profile: return nil
        case .account: return "Account"
        case .session: return nil
        }
    }

    var rows: [ProfileRow] {
        switch self {
        case .profile: return [.profileSummary]
        case .account: return [.personalInfo, .settings]
        case .session: return [.logout]
        }
    }
}

enum ProfileRow {
    case profileSummary
    case personalInfo
    case settings
    case logout

    var title: String {
        switch self {
        case .profileSummary: return ""
        case .personalInfo: return "Personal Information"
        case .settings: return "Settings"
        case .logout: return "Log out"
        }
    }

    var accessory: UITableViewCell.AccessoryType {
        switch self {
        case .logout, .profileSummary: return .none
        default: return .disclosureIndicator
        }
    }

    var isDestructive: Bool { self == .logout }
}
