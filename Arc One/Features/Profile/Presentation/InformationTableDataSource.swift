//
//  InformationTableDataSource.swift
//  Arc One
//
//  Created by Felipe Trejos on 22/12/25.
//

import UIKit

final class InformationTableDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {

    var items: [(title: String, value: String)] = []

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
