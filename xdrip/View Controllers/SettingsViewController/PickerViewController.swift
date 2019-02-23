import UIKit

final class PickerViewController : UIViewController {
  
    //MARK: - Properties
    
    /// title to use for pickerview
    var pickerTitle:String?
    
    /// will have the soure data in the pickerview
    var dataSource:[String] = []
    
    /// selectedIndex, initial value can be set by parent uiviewcontroller
    var selectedRow:Int?
    
    /// name of button that allows user to select, ie the "Ok" button
    var addButtonTitle:String?
    
    /// name of button that allows user to cancel, ie the "Cancel" button
    var cancelButtonTitle:String?
    
    // handler to executed when user clicks actionButton
    var addHandler:((_ index: Int) -> Void) = {_ in fatalError("in PickerViewController, actionHandler is nil")}
    
    /// handler to execute when user clicks cancelHandler
    var cancelHandler:(() -> Void)?
    
    //MARK: Actions
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        // call cancelhandler
        if let cancelHandler = cancelHandler { cancelHandler() }
    }
    
    @IBAction func addButtonPressed(_ sender: Any) {
        // call actionhandler
        if let selectedIndex = selectedRow { addHandler(selectedIndex) }
    }
    
    //MARK: Outlets
    
    // label on top of the pickerview
    @IBOutlet weak var pickerViewTitle: UILabel!
    
    // the pickerview itself
    @IBOutlet weak var pickerView: UIPickerView!
    
    // the button to cancel and go back to previous screen
    @IBOutlet weak var cancelButton: UIButton!
    
    // the button to confirm changes
    @IBOutlet weak var addButton: UIButton!
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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
        
        // set title of pickerview
        if let pickerTitle = pickerTitle {
            pickerViewTitle.text = pickerTitle
        }
    }
}

extension PickerViewController:UIPickerViewDelegate {
    
    // MARK: - UIPickerViewDelegate protocol Methods
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return dataSource[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedRow = row
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
