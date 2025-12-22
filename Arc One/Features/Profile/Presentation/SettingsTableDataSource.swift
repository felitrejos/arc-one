//
//  SettingsTableDataSource.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import UIKit

final class SettingsTableDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {

    var provider: AuthProvider = .password
    var onRowSelected: ((SettingsRow) -> Void)?

    private func rows(in sectionIndex: Int) -> [SettingsRow] {
        guard let section = SettingsSection(rawValue: sectionIndex) else { return [] }
        return section.rows(for: provider)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows(in: section).count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        SettingsSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)

        let row = rows(in: indexPath.section)[indexPath.row]
        cell.textLabel?.text = row.title
        cell.accessoryType = row.accessory
        cell.textLabel?.textColor = row.isDestructive ? .systemRed : .label
        cell.selectionStyle = .default

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows(in: indexPath.section)[indexPath.row]
        onRowSelected?(row)
    }
}
