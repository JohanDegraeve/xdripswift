import UIKit

class SettingsTableViewCell: UITableViewCell {
    
    // MARK: - Type Properties
    
    static let reuseIdentifier = "SettingsCell"
    
    /// single instance of a view with backgroundColor = custom color
    private static var selectedBackGroundView: UIView = {
     
            let backgroundView = UIView()
            
            backgroundView.backgroundColor = ConstantsUI.tableRowSelectedBackGroundColor
            
            return backgroundView

    }()
    
    override
    init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // will set color when selected to own color
        selectedBackgroundView = SettingsTableViewCell.selectedBackGroundView

    }
    
    required
    init?(coder: NSCoder) {
        
        super.init(coder: coder)

        // will set color when selected to own color
        selectedBackgroundView = SettingsTableViewCell.selectedBackGroundView

    }
    
}
