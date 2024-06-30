import UIKit

final class PickerViewController : UIViewController {
  
    //MARK: - Properties

    /// maintitle to use for pickerview
    var mainTitle:String?
    
    /// subtitle to use for pickerview
    var subTitle:String?
    
    /// will have the soure data in the pickerview
    var dataSource:[String] = []
    
    /// selectedIndex, initial value can be set by parent uiviewcontroller
    var selectedRow:Int?
    
    /// name of button that allows user to select, ie the "Ok" button
    var addButtonTitle:String?
    
    /// name of button that allows user to cancel, ie the "Cancel" button
    var cancelButtonTitle:String?
    
    // handler to executed when user clicks actionButton
    var addHandler:((_ index: Int) -> Void) = {_ in fatalError("in PickerViewController, actionHandler is not initialized")}
    
    /// handler to execute when user clicks cancelHandler
    var cancelHandler:(() -> Void)?
    
    /// will be called when user change selection before clicking ok or cancel button
    var didSelectRowHandler:((Int) -> Void)?
    
    /// priority to be applied
    private var priority:PickerViewPriority?
    
    //MARK: Actions
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        // call cancelhandler
        if let cancelHandler = cancelHandler { cancelHandler() }
        
        // remove the uiviewcontroller
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func addButtonPressed(_ sender: Any) {
        // call actionhandler
        if let selectedIndex = selectedRow { addHandler(selectedIndex) }
        
        // remove the uiviewcontroller
        self.dismiss(animated: true, completion: nil)
        
        // force a state change so that the observer in RVC will pick it up and refresh the snooze icon state
        UserDefaults.standard.updateSnoozeStatus = !UserDefaults.standard.updateSnoozeStatus

    }
    
    //MARK: Outlets
    
    // maintitle on top of the pickerview
    @IBOutlet weak var pickerViewMainTitle: UILabel!
    
    // subtitle on top of the pickerview
    @IBOutlet weak var pickerViewSubTitle: UILabel!
    
    // the pickerview itself
    @IBOutlet weak var pickerView: UIPickerView!
    
    // the button to cancel and go back to previous screen
    @IBOutlet weak var cancelButton: UIButton!
    
    // the button to confirm changes
    @IBOutlet weak var addButton: UIButton!
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupView()
    }
    
    // MARK: - View Methods
    
    private func setupView() {

        //data source
        pickerView.dataSource = self
        
        //delegate
        pickerView.delegate = self

        //set actionTitle
        if let addButtonTitle = addButtonTitle {
            addButton.setTitle(addButtonTitle, for: .normal)
        } else {
            addButton.setTitle(Texts_Common.Ok, for: .normal)
        }
        
        //set cancelTitle
        if let cancelButtonTitle = cancelButtonTitle {
            cancelButton.setTitle(cancelButtonTitle, for: .normal)
        } else {
            cancelButton.setTitle(Texts_Common.Cancel, for: .normal)
        }
        
        // set selectedRow
        if let selectedRow = selectedRow {
            pickerView.selectRow(selectedRow, inComponent: 0, animated: false)
        }
        
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
        
        /// TODO:- the actual color to be used should be defined somewhere else
        // if priority defined then if high priority, apply other color
        if let priority = priority {
            switch priority {
                
            case .normal:
                break
            case .high:
                pickerViewMainTitle.textColor = UIColor.red
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// creates and presents a new PickerViewController in the parentController - if there's already another uiviewcontroller being presented by the specified parentController, then the cancelhandler will be called immediately without trying to present anything
    /// - parameters:
    ///     - pickerViewData : data to use in the pickerviewcontroller
    ///     - parentController : the parentController to which the pickerviewcontroller will be added
    public static func displayPickerViewController(pickerViewData:PickerViewData, parentController:UIViewController) {
        
        let pickerViewController = UIStoryboard.main.instantiateViewController(withIdentifier: "PickerViewController") as! PickerViewController
        pickerViewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        
        //configure pickerViewController
        pickerViewController.mainTitle = pickerViewData.mainTitle != nil ? pickerViewData.mainTitle:""
        pickerViewController.subTitle = pickerViewData.subTitle != nil ? pickerViewData.subTitle:""
        pickerViewController.dataSource = pickerViewData.data
        pickerViewController.selectedRow = pickerViewData.selectedRow
        pickerViewController.addButtonTitle = pickerViewData.actionTitle
        pickerViewController.cancelButtonTitle = pickerViewData.cancelTitle
        pickerViewController.priority = pickerViewData.priority
        pickerViewController.addHandler = {(_ index: Int) in
            pickerViewController.dismiss(animated: true, completion: nil)
            pickerViewData.actionHandler(index)
        }
        pickerViewController.cancelHandler = {
            pickerViewController.dismiss(animated: true, completion: nil)
            if let cancelHandler = pickerViewData.cancelHandler { cancelHandler() }
        }
        pickerViewController.didSelectRowHandler = pickerViewData.didSelectRowHandler
        
        // present it
        parentController.present(pickerViewController, animated: true)

    }


}

extension PickerViewController:UIPickerViewDelegate {
    
    // MARK: - UIPickerViewDelegate protocol Methods
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return dataSource[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        // set selectedRow to row, value will be used when pickerview is closed
        selectedRow = row
        
        // call also didSelectRowHandler, if not nil, can be useful eg when pickerview contains list of sounds, sound can be played
        if let didSelectRowHandler = didSelectRowHandler {
            didSelectRowHandler(row)
        }
    }
}

extension PickerViewController:UIPickerViewDataSource {
    
    // MARK: - UIPickerViewDataSource protocol Methods
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dataSource.count
    }
    
}
