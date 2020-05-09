import UIKit

final class DatePickerViewController: UIViewController {
    
    //MARK: - Properties
    
    /// maintitle to use for pickerview
    var mainTitle:String?
    
    /// subtitle to use for pickerview
    var subTitle:String?
    
    /// name of button that allows user to select, ie the "Ok" button
    var addButtonTitle:String?
    
    /// name of button that allows user to cancel, ie the "Cancel" button
    var cancelButtonTitle:String?
    
    // handler to executed when user clicks actionButton
    var okHandler:((_ date: Date) -> Void) = {_ in fatalError("in PickerViewController, okHandler is not initialized")}
    
    /// handler to execute when user clicks cancelHandler
    var cancelHandler:(() -> Void)?
    
    /// default date to set
    var date:Date?
    
    /// if minimumDate defined
    var minimumDate:Date?
    
    /// if maximumDate defined
    var maximumDate:Date?
    
    /// datepickermode
    var datePickerMode:UIDatePicker.Mode?
    
    //MARK: Actions
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        
        // call cancelhandler
        if let cancelHandler = cancelHandler { cancelHandler() }
        
        // remove the uiviewcontroller
        self.dismiss(animated: true, completion: nil)

    }
    
    @IBAction func okButtonPressed(_ sender: UIButton) {
        
        // call okHandler
        okHandler(datePickerView.date)
        
        // remove the uiviewcontroller
        self.dismiss(animated: true, completion: nil)
        
    }
    
    //MARK: Outlets
    
    @IBOutlet weak var pickerViewMainTitle: UILabel!
    
    @IBOutlet weak var pickerViewSubTitle: UILabel!
    
    @IBOutlet weak var datePickerView: UIDatePicker!
    
    @IBOutlet weak var cancelButton: UIButton!
    
    @IBOutlet weak var okButton: UIButton!
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupView()
    }
    
    // MARK: - View Methods
    
    private func setupView() {
        
        //set okTitle
        if let addButtonTitle = addButtonTitle {
            okButton.setTitle(addButtonTitle, for: .normal)
        } else {
            okButton.setTitle(Texts_Common.Ok, for: .normal)
        }
        
        //set cancelTitle
        if let cancelButtonTitle = cancelButtonTitle {
            cancelButton.setTitle(cancelButtonTitle, for: .normal)
        } else {
            cancelButton.setTitle(Texts_Common.Cancel, for: .normal)
        }
        
        // set the date
        if let date = date {datePickerView.setDate(date, animated: true)}
        
        // set datepickermode
        if let datePickerMode = datePickerMode {datePickerView.datePickerMode = datePickerMode}
        
        // set maximum date
        if let maximumDate = maximumDate {datePickerView.maximumDate = maximumDate}
        
        // set minimum date
        if let minimumDate = minimumDate {datePickerView.minimumDate = minimumDate}
        
        // set picker maintitle
        if let mainTitle = mainTitle {
            pickerViewMainTitle.text = mainTitle
        } else {
            pickerViewMainTitle.text = ""
        }
        
        // set title of pickerview
        if let subTitle = subTitle {
            pickerViewSubTitle.text = subTitle
        }
        
    }
    
    // MARK: - Public Methods
    
    public static func displayDatePickerViewController(datePickerViewData:DatePickerViewData, parentController:UIViewController) {
        
        // check if there's already another uiviewcontroller being presented, if so just call the cancelhandler
        if parentController.presentedViewController == nil {
            
            let datePickerViewController = UIStoryboard.main.instantiateViewController(withIdentifier: "DatePickerViewController") as! DatePickerViewController
            datePickerViewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
            
            //configure pickerViewController
            
            datePickerViewController.mainTitle = datePickerViewData.mainTitle != nil ? datePickerViewData.mainTitle:""
            datePickerViewController.subTitle = datePickerViewData.subTitle != nil ? datePickerViewData.subTitle:""
            
            datePickerViewController.addButtonTitle = datePickerViewData.okTitle
            datePickerViewController.cancelButtonTitle = datePickerViewData.cancelTitle
            
            datePickerViewController.date = datePickerViewData.date
            datePickerViewController.datePickerMode = datePickerViewData.datePickerMode
            datePickerViewController.minimumDate = datePickerViewData.minimumDate
            datePickerViewController.maximumDate = datePickerViewData.maximumDate
            
            datePickerViewController.okHandler = {(_ date: Date) in
                datePickerViewData.okHandler(date)
                datePickerViewController.dismiss(animated: true, completion: nil)
            }
            
            datePickerViewController.cancelHandler = {
                datePickerViewController.dismiss(animated: true, completion: nil)
                if let cancelHandler = datePickerViewData.cancelHandler { cancelHandler() }
            }
            
            // present it
            parentController.present(datePickerViewController, animated: true)
            
        } else {
            if let cancelHandler = datePickerViewData.cancelHandler { cancelHandler() }
        }
    }
}
