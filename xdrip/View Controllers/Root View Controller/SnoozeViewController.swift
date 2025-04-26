import UIKit

final class SnoozeViewController: UIViewController {
    
    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var snoozeAllLabel: UILabel!
    @IBOutlet weak var snoozeAllUISwitch: UISwitch!
    @IBOutlet weak var snoozeAllBannerView: UIView!
    @IBOutlet weak var snoozeAllBannerText: UILabel!
    
    // if the UISwitch is tapped, change it's state. If changed to isOn then show Snooze Picker and pass the value back to the view
    @IBAction func snoozeAllUISwitchAction(_ sender: Any) {
        if UserDefaults.standard.snoozeAllAlertsFromDate == nil {
            let defaultSnoozeAllPeriodInMinutes = ConstantsAlerts.defaultSnoozeAllPeriodInMinutes
            let snoozeAllValueMinutes = ConstantsAlerts.snoozeAllValueMinutes
            var defaultRow = 0
            
            for (index, _) in snoozeAllValueMinutes.enumerated() {
                if snoozeAllValueMinutes[index] > defaultSnoozeAllPeriodInMinutes {
                    break
                } else {
                    defaultRow = index
                }
            }
            
            let pickerViewData = PickerViewData(withMainTitle: Texts_HomeView.snoozeAllTitle, 
                                                withSubTitle: Texts_Alerts.selectSnoozeTime,
                                                withData: ConstantsAlerts.snoozeAllValueStrings,
                                                selectedRow: defaultRow,
                                                withPriority: .high,
                                                actionButtonText: Texts_Common.Ok,
                                                cancelButtonText: Texts_Common.Cancel,
                                                isFullScreen: true,
                                                onActionClick: {
                (snoozeIndex:Int) -> Void in
                
                // get snooze period
                let snoozePeriod = snoozeAllValueMinutes[snoozeIndex]
                
                UserDefaults.standard.snoozeAllAlertsFromDate = Date()
                UserDefaults.standard.snoozeAllAlertsUntilDate = Date().addingTimeInterval(Double(snoozePeriod) * 60)
                
                // update the view
                self.configureSnoozeAllView()
            },
                                                onCancelClick: { () -> Void in
                // update the view
                self.configureSnoozeAllView()
            },
                                                didSelectRowHandler: nil
            )
            
            // create and display pickerViewData
            PickerViewControllerModal.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
        } else {
            UserDefaults.standard.snoozeAllAlertsFromDate = nil
            UserDefaults.standard.snoozeAllAlertsUntilDate = nil
            
            // now we've reset everything, update the view
            configureSnoozeAllView()
        }
    }
    
    // reference to alertManager
    private var alertManager: AlertManager?
    
    // MARK: - Public functions
    
    public func configure(alertManager: AlertManager?) {
        self.alertManager = alertManager
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = Texts_HomeView.snoozeButton
        snoozeAllLabel.text = Texts_HomeView.snoozeAllTitle
        snoozeAllBannerView.layer.cornerRadius = 10
        snoozeAllBannerView.layer.masksToBounds = true
        
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // restrict rotation of the Snooze View to just portrait. This is important as it is a child view of RootViewController
        (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
        
        configureSnoozeAllView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // as the snooze view is removed, all the RootViewController to rotate again if permitted
        if UserDefaults.standard.allowScreenRotation {
            (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .allButUpsideDown
        } else {
            (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
        }
        
        // force a state change so that the observer in RVC will pick it up and refresh the snooze icon state
        UserDefaults.standard.updateSnoozeStatus = !UserDefaults.standard.updateSnoozeStatus
    }
    
    // MARK: - private helper functions
    
    // setup the view
    private func setupView() {
        setupTableView()
    }
    
    /// setup datasource, delegate, seperatorInset
    private func setupTableView() {
        if let tableView = tableView {
            // insert slightly the separator text so that it doesn't touch the safe area limit
            tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
            tableView.dataSource = self
            tableView.delegate = self
        }
    }
    
    private func configureSnoozeAllView() {
        if alertManager?.snoozeStatus() == .allSnoozed, let snoozeAllAlertsUntilDate = UserDefaults.standard.snoozeAllAlertsUntilDate {
            // if snoozed till after 00:00 then show date and time when it ends, else only show time
            self.snoozeAllUISwitch.isOn = true
            snoozeAllBannerText.text = "\(Texts_HomeView.snoozeAllSnoozed)\n\(snoozeAllAlertsUntilDate.daysAndHoursRemaining(appendRemaining: true))"
            snoozeAllBannerText.textColor = .white
            snoozeAllBannerView.backgroundColor = .systemRed
            snoozeAllLabel.textColor = .systemRed
        } else if alertManager?.snoozeStatus() == .urgent {
            UserDefaults.standard.snoozeAllAlertsFromDate = nil
            self.snoozeAllUISwitch.isOn = false
            snoozeAllBannerView.backgroundColor = ConstantsAlerts.bannerBackgroundColorWhenNotAllSnoozed
            snoozeAllBannerText.text = Texts_HomeView.snoozeUrgentAlarms
            snoozeAllBannerText.textColor = .systemRed
            snoozeAllLabel.textColor = UIColor(named: "colorPrimary")
        } else {
            UserDefaults.standard.snoozeAllAlertsFromDate = nil
            self.snoozeAllUISwitch.isOn = false
            snoozeAllBannerView.backgroundColor = ConstantsAlerts.bannerBackgroundColorWhenNotAllSnoozed
            snoozeAllBannerText.text = Texts_HomeView.snoozeAllDisabled
            snoozeAllBannerText.textColor = ConstantsAlerts.bannerTextColorWhenNotAllSnoozed
            snoozeAllLabel.textColor = UIColor(named: "colorPrimary")
        }
    }
}

// MARK: - Conform to UITableViewDataSource

extension SnoozeViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        // number of sections corresponds to number of alarm types
        return AlertKind.allCases.count
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // just one row per alarm type
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        // alertKind corresponds to section number
        guard let alertKind = AlertKind(forSection: indexPath.section) else {
            fatalError("In SnoozeViewController, cellForRowAt, could not create alertKind")
        }
        
        // unwrap alertManager
        guard let alertManager = alertManager else {
            fatalError("In SnoozeViewController, cellForRowAt, alertmanager is nil")
        }
        
        // get snoozeParameters for the alertKind
        let (isSnoozed, remainingSeconds) = alertManager.getSnoozeParameters(alertKind: alertKind).getSnoozeValue()
        
        if isSnoozed {
            
            guard let remainingSeconds = remainingSeconds else {
                fatalError("In SnoozeViewController, remainingSeconds is nil but alert is snoozed")
            }
            
            // till when snoozed, as Date
            let snoozedTillDate = Date(timeIntervalSinceNow: Double(remainingSeconds))
            
            // if snoozed till after 00:00 then show date and time when it ends, else only show time
            let showDate = snoozedTillDate.toMidnight() > Date()
            
            cell.textLabel?.text = TextsSnooze.snoozed_until + " " + (showDate ? snoozedTillDate.formatted(date: .abbreviated, time: .shortened) : snoozedTillDate.formatted(date: .omitted, time: .shortened))//.toStringInUserLocale(timeStyle: .short, dateStyle: showDate ? .short : .none)  // "\u{26A0} " +
            cell.textLabel?.textColor = .white
            
        } else {
            
            cell.textLabel?.text = TextsSnooze.not_snoozed
            cell.textLabel?.textColor = .gray
            
        }
        
        // no detailed text to be shown, the snooze time is already given in the textLabel
        cell.detailTextLabel?.text = nil
        
        // no accessory type to be shown
        cell.accessoryType = .none
        
        // uiswitch will be on if currently snoozed, off if currently not snoozed
        cell.accessoryView = UISwitch(isOn: isSnoozed, action: { (isOn:Bool) in
            
            // closure to reload the row after user clicked form on to off, or from off to on and selected a snoozeperiod
            let reloadRow = { tableView.reloadRows(at: [IndexPath(row: 0, section: indexPath.section)], with: .none)}
            
            // changing from off to on. Means user wants to pre-snooze
            if isOn {
                // create and display pickerViewData
                PickerViewControllerModal.displayPickerViewController(pickerViewData: alertManager.createPickerViewData(forAlertKind: alertKind, content: nil, actionHandler: {
                    reloadRow()
                    self.configureSnoozeAllView()
                }, cancelHandler: {
                    reloadRow()
                    alertManager.unSnooze(alertKind: alertKind)
                }), parentController: self)
                
            } else {
                // changing from on to off. Means user wants to unsnooze
                alertManager.unSnooze(alertKind: alertKind)
                self.configureSnoozeAllView()
                reloadRow()
            }
        })
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        // alertKind corresponds to section number
        guard let alertKind = AlertKind(forSection: section) else {
            fatalError("In titleForHeaderInSection, could not create alertKind")
        }
        
        return (alertKind.alertUrgencyType() == .urgent ? "\u{2757}" : "") + alertKind.alertTitle()
        
    }
    
}

// MARK: - Conform to UITableViewDelegate

extension SnoozeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        if let view = view as? UITableViewHeaderFooterView {
            
            view.textLabel?.textColor = ConstantsUI.tableViewHeaderTextColor
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
}

// MARK: - SegueIdentifiers

extension SnoozeViewController {
    
    public enum SegueIdentifiers: String {
        
        /// to go from RootViewController to SnoozeViewController
        case RootViewToSnoozeView = "RootViewToSnoozeView"
        
    }
    
}
