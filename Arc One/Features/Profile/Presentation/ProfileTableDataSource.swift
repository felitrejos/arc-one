//
//  ProfileTableDataSource.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import UIKit

final class ProfileTableDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {

    // Inputs
    var profileName: String = ""
    var profileEmail: String = ""
    var profileAvatar: UIImage = UIImage(systemName: "person.crop.circle.fill")!

    // Outputs
    var onRowSelected: ((ProfileRow) -> Void)?

    func numberOfSections(in tableView: UITableView) -> Int {
        ProfileSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = ProfileSection(rawValue: section) else { return 0 }
        return section.rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ProfileSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let section = ProfileSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        let row = section.rows[indexPath.row]

        if row == .profileSummary {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "ProfileSummaryCell",
                for: indexPath
            ) as! ProfileSummaryCell

            cell.selectionStyle = .none
            cell.configure(name: profileName, email: profileEmail, avatar: profileAvatar)
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath)
        cell.textLabel?.text = row.title
        cell.accessoryType = row.accessory
        cell.textLabel?.textColor = row.isDestructive ? .systemRed : .label
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = ProfileSection(rawValue: indexPath.section) else { return }
        let row = section.rows[indexPath.row]
        if row == .profileSummary { return }

        onRowSelected?(row)
    }
}
