//
//  InformationController.swift
//  Arc One
//
//  Created by Felipe Trejos on 13/12/25.
//

import UIKit

final class InformationController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private let ds = InformationTableDataSource()
    private let profileService = ProfileService()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Information"

        tableView.dataSource = ds
        tableView.delegate = ds

        if tableView.dequeueReusableCell(withIdentifier: "informationCell") == nil {
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "informationCell")
        }

        loadInfo()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadInfo()
    }

    private func loadInfo() {
        profileService.loadInformationItems { [weak self] items in
            guard let self else { return }
            self.ds.items = items
            self.tableView.reloadData()
        }
    }
}
