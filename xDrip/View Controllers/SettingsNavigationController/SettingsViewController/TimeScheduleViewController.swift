import UIKit

/// - shows list of timestamps (hour:minute) , with detailed text starting with On and switching to off, on, ...
/// - to be used to create on/off schedule eg for nightscout upload
final class TimeScheduleViewController: UIViewController {
    
    // MARK: - Outlets, ..
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func addButtonAction(_ sender: UIBarButtonItem) {
        addButtonHandler()
    }
    
    @IBOutlet weak var topLabelOutlet: UILabel!
    
    // MARK: - Private Properties
    
    var schedule: Array<Int>!
    
    var serviceName: String!
    
    var timeSchedule: TimeSchedule!
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        setupView()
        
    }
    
    // MARK: - Public functions
    
    /// - parameters:
    ///     - timeSchedule : TimeSchedule protocol defines a getter and setter method for schedule that is stored in userdefaults, and also the serviceName
    ///
    /// Example, :
    /// - schedule = [5, 480, 660, 1080]
    /// - at 00:00 the value is on, at 00:05 the value will be off, at 08:00 (480 minutes) on, at 11:00 off, at 18:00 on
    public func configure(timeSchedule: TimeSchedule) {
        
        self.schedule = [0] + timeSchedule.getSchedule()
        
        self.serviceName = timeSchedule.serviceName()
        
        self.timeSchedule = timeSchedule
        
    }
    
    // MARK: - Private helper functions
    
    private func setupView() {
        
        setupTableView()
        
        topLabelOutlet.text = Texts_SettingsView.timeScheduleViewTitle + " " + serviceName

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
    
    /// - helper function used in addButtonHandler and tableView didSelectRowAt
    /// - will show time picker which lets user select new time.
    /// - if it's an existing schedule being updated, then the cancel button will be replaced by delete text, and if pressed, delete the schedule
    /// - parameters:
    ///     - minimumStart : minimum time in minutes
    ///     - maximumStart : maximum time in minutes
    ///     - indexInSchedule : if nil, then it's for appending a new schedule to the end of the schedule, alse it's for updating an entry in the schedule
    ///     - onCancelClick :
    private func showTimePicker(minimumStart: Int, maximumStart: Int, indexInSchedule: Int?) {
        
        // create Date that represents now, locally, at 00:00
        let nowAt000 = Date().toMidnight()

        // date is either minimumStart + 1 (if adding a new schedule) or the schedule pointed to by indexInSchedule
        var date = Date(timeInterval: TimeInterval(Double(minimumStart + 1) * 60.0), since: nowAt000)
        if let indexInSchedule = indexInSchedule {
            date = Date(timeInterval: TimeInterval(Double(schedule[indexInSchedule]) * 60.0), since: nowAt000)
        }
        
        // index of schedule that will be edited or added
        let indexNewOrUpdatedSchedule = indexInSchedule == nil ? schedule.count : indexInSchedule!
        
        // create subTitle
        let subTitle = Texts_SettingsView.editScheduleTimePickerSubtitle + " " + (indexNewOrUpdatedSchedule % 2 == 0 ? (Texts_Common.off + " -> " + Texts_Common.on) : (Texts_Common.on + " -> " + Texts_Common.off))
        
        // create date pickerviewdata
        let datePickerViewData = DatePickerViewData(withMainTitle: nil, withSubTitle: subTitle, datePickerMode: .time, date: date, minimumDate: Date(timeInterval: TimeInterval(Double(minimumStart + 1) * 60.0), since: nowAt000), maximumDate: Date(timeInterval: TimeInterval(Double(maximumStart - 1) * 60.0), since: nowAt000), okButtonText: nil, cancelButtonText: indexInSchedule == nil ? nil : Texts_Common.delete
            , onOkClick: {(newdate) in
                
                if indexInSchedule == nil {
                    // set new start value
                    self.schedule.append(newdate.minutesSinceMidNightLocalTime())
                } else {
                    self.schedule[indexInSchedule!] = newdate.minutesSinceMidNightLocalTime()
                }
                
                self.storeTheScheduleAndReloadTheTable()
                
        }, onCancelClick: {
            
            // if indexInSchedule is nil, then no additional action on cancel
            guard let indexInSchedule = indexInSchedule else {return}
            
            // cancel is actually delete
            // ask confirmation before deleting
            // first ask user if ok to delete and if yes delete
            let alert = UIAlertController(title: Texts_Common.delete + " ?", message: nil, actionHandler: {
                
                self.schedule.remove(at: indexInSchedule)
                
                self.storeTheScheduleAndReloadTheTable()

            }, cancelHandler: nil)
            
            self.present(alert, animated:true)
            
        })
        
        // present datepickerview
        DatePickerViewController.displayDatePickerViewController(datePickerViewData: datePickerViewData, parentController: self)

    }
    
    private func storeTheScheduleAndReloadTheTable() {
        
        // store the new schedule
        if self.schedule.count > 1 {
            self.timeSchedule.storeSchedule(schedule: Array(self.schedule[1...self.schedule.count-1]))
        } else {
            self.timeSchedule.storeSchedule(schedule: [Int]())
        }
        
        // table needs reload to show new value
        self.tableView.reloadData()

    }
    
    private func addButtonHandler() {
        
        // what is the minimum value
        let minimumStart: Int = schedule[schedule.count - 1]
        
        // what is the maximum value
        let maximumStart: Int = 1440

        showTimePicker(minimumStart: minimumStart, maximumStart: maximumStart, indexInSchedule: nil)

    }
    
}

extension TimeScheduleViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return schedule.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        // example 60 will be convered to 01:00, or 5 to 00:05
        cell.textLabel?.text = Int(schedule[indexPath.row]).convertMinutesToTimeAsString()
        
        // odd rows are off, even are on
        cell.detailTextLabel?.text = indexPath.row % 2 == 0 ? Texts_Common.on : Texts_Common.off
        
        // first row can't be edited
        if indexPath.row == 0 {
            cell.accessoryType = .none
        } else {
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
        }
        
        return cell
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }

}

extension TimeScheduleViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        if let view = view as? UITableViewHeaderFooterView {
            
            view.textLabel?.textColor = ConstantsUI.tableViewHeaderTextColor
            
        }
        
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.row == 0 {return}
        
        // what is the minimum value
        let minimumStart: Int = indexPath.row == 0 ? 0 : schedule[indexPath.row - 1]
        
        // what is the maximum value
        let maximumStart: Int = indexPath.row == schedule.count - 1 ? 1440 : schedule[indexPath.row + 1]
        
        showTimePicker(minimumStart: minimumStart, maximumStart: maximumStart, indexInSchedule: indexPath.row)
        
    }
    
}

/// protocol that defines
/// - functions to get and store the schedule from and to the UserDefaults
/// - also name of the service, eg Nightscout, this is just to show in the UI
protocol TimeSchedule {
    
    /// get the schedule as array of int
    func getSchedule() -> [Int]
    
    /// store the schedule
    func storeSchedule(schedule: [Int])
    
    /// name of the service, eg Nightscout, this is just to show in the UI
    func serviceName() -> String
    
}


