//
//  InformationController.swift
//  Arc One
//
//  Created by Felipe Trejos on 13/12/25.
//

import UIKit
import FirebaseAuth

final class InformationController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private var items: [(title: String, value: String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Information"

        tableView.dataSource = self
        tableView.delegate = self

        if tableView.dequeueReusableCell(withIdentifier: "informationCell") == nil {
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "informationCell")
        }

        loadInfo()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshUserAndReload()
    }

    // MARK: - Refresh user

    private func refreshUserAndReload() {
        guard let user = Auth.auth().currentUser else {
            loadInfo()
            tableView.reloadData()
            return
        }

        user.reload { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadInfo()
                self?.tableView.reloadData()
            }
        }
    }

    // MARK: - Load info

    private func loadInfo() {
        guard let user = Auth.auth().currentUser else {
            items = [("Status", "Not logged in")]
            return
        }

        let providers = user.providerData
            .map { prettyProviderName($0.providerID) }
            .joined(separator: ", ")

        let creation = user.metadata.creationDate.map { formatDate($0) } ?? "—"
        let lastSignIn = user.metadata.lastSignInDate.map { formatDate($0) } ?? "—"

        items = [
            ("Name", user.displayName ?? "—"),
            ("Email", user.email ?? "—"),
            ("Email verified", user.isEmailVerified ? "Yes" : "No"),
            ("Phone", user.phoneNumber ?? "—"),
            ("Login method", providers.isEmpty ? "—" : providers),
            ("Account created", creation),
            ("Last sign-in", lastSignIn)
        ]
    }

    // MARK: - Helpers

    private func prettyProviderName(_ providerID: String) -> String {
        switch providerID {
        case "google.com": return "Google"
        case "password": return "Email & Password"
        default: return providerID
        }
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

extension InformationController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "informationCell", for: indexPath)
        let item = items[indexPath.row]

        var content = UIListContentConfiguration.valueCell()
        content.text = item.title
        content.secondaryText = item.value
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content

        cell.selectionStyle = .none
        return cell
    }
}
