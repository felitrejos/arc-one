import UIKit

final class PortfolioTableDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {

    var holdings: [HoldingViewModel] = []
    var performanceMode: PerformanceMode = .sinceBuy

    var onAddTapped: (() -> Void)?
    var onHoldingTapped: ((HoldingViewModel) -> Void)?

    private let addCellId = "investmentCell"
    private let customCellId = "investmentCustomCell"

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        holdings.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.row == holdings.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: addCellId)
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: addCellId)

            cell.textLabel?.text = holdings.isEmpty ? "Add your first investment" : "Add an investment"
            cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            cell.textLabel?.textColor = tableView.tintColor

            cell.detailTextLabel?.text = nil
            cell.imageView?.image = UIImage(systemName: "plus.circle.fill")
            cell.imageView?.tintColor = tableView.tintColor
            cell.accessoryView = nil
            cell.selectionStyle = .default

            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: customCellId, for: indexPath) as! InvestmentCell
        let vm = holdings[indexPath.row]

        cell.configure(
            name: vm.name,
            amountText: vm.valueText,
            percentText: vm.changeText(for: performanceMode),
            percentColor: vm.changeColor(for: performanceMode),
            icon: vm.icon
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.row == holdings.count {
            onAddTapped?()
            return
        }

        onHoldingTapped?(holdings[indexPath.row])
    }
}
