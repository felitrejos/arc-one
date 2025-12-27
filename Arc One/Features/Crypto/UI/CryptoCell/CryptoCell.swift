import UIKit

final class CryptoCell: UITableViewCell {

    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var percentLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        selectionStyle = .default

        iconImageView.layer.cornerRadius = 8
        iconImageView.clipsToBounds = true

        nameLabel.textColor = .label
        amountLabel.textColor = .secondaryLabel
        percentLabel.font = .systemFont(ofSize: 14, weight: .bold)
    }

    func configure(
        name: String,
        amountText: String,
        percentText: String,
        percentColor: UIColor,
        icon: UIImage?
    ) {
        nameLabel.text = name
        amountLabel.text = amountText
        percentLabel.text = percentText
        percentLabel.textColor = percentColor
        iconImageView.image = icon
    }
}
