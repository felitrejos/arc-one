//
//  SettingsController.swift
//  Arc One
//
//  Created by Felipe Trejos on 13/12/25.
//

import UIKit

final class SettingsController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private let ds = SettingsTableDataSource()
    private let settingsService = SettingsService()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"

        tableView.dataSource = ds
        tableView.delegate = ds

        if tableView.dequeueReusableCell(withIdentifier: "settingsCell") == nil {
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "settingsCell")
        }

        ds.onRowSelected = { [weak self] row in
            guard let self else { return }

            switch row {
            case .editProfile:
                self.settingsService.editProfileInline(from: self) { result in
                    if case .failure(let err) = result {
                        self.showOKAlert(title: "Error", message: err.localizedDescription)
                    } else {
                        self.tableView.reloadData()
                    }
                }

            case .changePassword:
                self.settingsService.changePassword(from: self) { result in
                    switch result {
                    case .success:
                        self.showOKAlert(title: "Updated", message: "Your password was updated.")
                    case .failure(let err):
                        self.showOKAlert(title: "Error", message: err.localizedDescription)
                    }
                }

            case .deleteAccount:
                self.settingsService.confirmDeleteAccount(from: self) { result in
                    switch result {
                    case .success:
                        self.settingsService.showLoginScreen(from: self)
                    case .failure(let err):
                        self.showOKAlert(title: "Error", message: err.localizedDescription)
                    }
                }

            case .terms:
                self.settingsService.openURL("https://policies.google.com/terms", from: self)

            case .privacy:
                self.settingsService.openURL("https://policies.google.com/privacy", from: self)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ds.provider = AuthProvider.current()
        tableView.reloadData()
    }

    private func showOKAlert(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
