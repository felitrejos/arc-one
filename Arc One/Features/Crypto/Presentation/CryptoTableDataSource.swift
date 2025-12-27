import UIKit

final class CryptoTableDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    
    var holdings: [CryptoHoldingViewModel] = []
    var performanceMode: CryptoPerformanceMode = .sinceBuy
    var onAddTapped: (() -> Void)?
    var onHoldingTapped: ((Int) -> Void)?
    
    private let marketService = CryptoMarketService()
    
    func numberOfSections(in tableView: UITableView) -> Int { 2 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? holdings.count : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cryptoCell", for: indexPath) as! InvestmentCell
            let vm = holdings[indexPath.row]
            
            cell.name.text = vm.symbol
            cell.value.text = vm.valueText
            cell.change.text = vm.changeText(for: performanceMode)
            cell.change.textColor = vm.changeColor(for: performanceMode)
            cell.icon.image = vm.icon
            cell.icon.layer.cornerRadius = 8
            cell.icon.clipsToBounds = true
            
            // Load icon async if not loaded
            if vm.icon == nil {
                Task {
                    if let profile = try? await marketService.fetchProfile(coinId: vm.coinId),
                       let url = profile.logoURL {
                        let image = await ImageLoader.shared.load(url)
                        if let visibleRows = tableView.indexPathsForVisibleRows,
                           visibleRows.contains(indexPath) {
                            cell.icon.image = image
                        }
                    }
                }
            }
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "addCell", for: indexPath)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            onHoldingTapped?(indexPath.row)
        } else {
            onAddTapped?()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 72 : 60
    }
}
