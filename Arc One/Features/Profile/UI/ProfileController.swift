//
//  ProfileController.swift
//  Arc One
//
//  Created by Felipe Trejos on 29/11/25.
//

import UIKit

final class ProfileController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private let ds = ProfileTableDataSource()
    private let profileService = ProfileService()
    private let settingsService = SettingsService()
    private var hasAppearedOnce = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        
        // Hide content initially
        view.alpha = 0

        tableView.dataSource = ds
        tableView.delegate = ds

        tableView.register(
            UINib(nibName: "ProfileSummaryCell", bundle: nil),
            forCellReuseIdentifier: "ProfileSummaryCell"
        )

        ds.onRowSelected = { [weak self] row in
            guard let self else { return }
            switch row {
            case .personalInfo:
                self.performSegue(withIdentifier: "showPersonalInfo", sender: self)
            case .settings:
                self.performSegue(withIdentifier: "showSettings", sender: self)
            case .logout:
                self.presentLogoutConfirm()
            case .profileSummary:
                break
            }
        }

        profileService.startListening { [weak self] state in
            guard let self else { return }
            self.ds.profileName = state.name
            self.ds.profileEmail = state.email
            self.ds.profileAvatar = state.avatar
            self.reloadProfileSummaryRow()
            self.fadeInIfNeeded()
        }
    }

    deinit {
        profileService.stopListening()
    }
    
    private func fadeInIfNeeded() {
        guard !hasAppearedOnce else { return }
        hasAppearedOnce = true
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1
        }
    }

    private func reloadProfileSummaryRow() {
        let indexPath = IndexPath(row: 0, section: ProfileSection.profile.rawValue)
        if tableView.numberOfSections > indexPath.section,
           tableView.numberOfRows(inSection: indexPath.section) > indexPath.row {
            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            tableView.reloadData()
        }
    }

    private func presentLogoutConfirm() {
        let alert = UIAlertController(
            title: "Log out?",
            message: "Are you sure you want to log out?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log out", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.settingsService.logoutAndShowLogin(from: self)
        })

        present(alert, animated: true)
    }
}
