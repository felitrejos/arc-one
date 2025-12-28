import UIKit

final class AnalyticsTableDataSource: NSObject, UITableViewDataSource {
    
    var holdings: [HoldingBreakdown] = []
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        holdings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "holdingBreakdownCell", for: indexPath) as! HoldingBreakdownCell
        let holding = holdings[indexPath.row]
        
        cell.configure(with: holding)
        
        return cell
    }
}
