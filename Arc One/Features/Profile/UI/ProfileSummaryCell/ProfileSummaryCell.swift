//
//  ProfileSummaryCell.swift
//  Arc One
//
//  Created by Felipe Trejos on 14/12/25.
//

import UIKit

final class ProfileSummaryCell: UITableViewCell {

    @IBOutlet private weak var avatarImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var emailLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImageView.clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2
    }

    func configure(name: String, email: String, avatar: UIImage) {
        nameLabel.text = name
        emailLabel.text = email
        avatarImageView.image = avatar
    }
}
