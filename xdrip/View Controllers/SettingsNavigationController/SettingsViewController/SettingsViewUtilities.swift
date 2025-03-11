import UIKit

/// defines static utility functions for view controllers
class SettingsViewUtilities {
    
    /// no init necessary
    private init() {
        
    }
    
    /// for cell at cellIndex and SectionIndex, configures the cell according to viewModel. tableView is needed because if UISwitch is in the list of settings, then a reload must be done whenever the switch changes value
    static func configureSettingsCell(cell: inout SettingsTableViewCell, forRowWithIndex rowIndex: Int, forSectionWithIndex sectionIndex: Int, withViewModel viewModel: SettingsViewModelProtocol, tableView: UITableView) {
        
        // first the two textfields
        cell.textLabel?.text = viewModel.settingsRowText(index: rowIndex)
        cell.detailTextLabel?.text = viewModel.detailedText(index: rowIndex)

        // if not enabled, then no need to adding anything else
        if viewModel.isEnabled(index: rowIndex) {

            // get accessoryView
            cell.accessoryView = viewModel.uiView(index: rowIndex)

            // setting enabled, get accessory type and accessory view
            cell.accessoryType = viewModel.accessoryType(index: rowIndex)
            
            //if accessoryType = disclosure indicator then use custom disclosureIndicator in ConstantsUI.disclosureIndicatorColor
            if cell.accessoryType == .disclosureIndicator {
                cell.accessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
            }
            
            // if uiview is an uiswitch then a reload must be initiated whenever the switch changes, either complete view or just the section
            if let view = cell.accessoryView as? UISwitch {
                view.addTarget(self, action: {
                    (theSwitch:UISwitch) in
                    
                    checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: viewModel, rowIndex: rowIndex, sectionIndex: sectionIndex)
                    
                }, for: UIControl.Event.valueChanged)
            }
            
        } else {
            
            // setting not enabled, set color to grey, no accessory type to be added
            cell.textLabel?.textColor = UIColor.gray
            cell.detailTextLabel?.textColor = UIColor.gray
            
            // set accessory and selectionStyle to none, because no action is required when user clicks the row
            cell.accessoryType = .none
            cell.selectionStyle = .none
            
            // set accessoryView to nil
            cell.accessoryView = nil
            
        }

    }
    
    /// for cell at cellIndex and SectionIndex, runs the selectedRowAction. tableView is needed because a reload must be done in some cases
    /// - parameters:
    ///     - withViewModel : need to know if refresh of the table is needed, can be nil in case a viewmodel is not used (eg M5StackViewController)
    ///     - tableView : need to know if refresh of the table is needed, can be nil in case a viewmodel is not used (eg M5StackViewController)
    static func runSelectedRowAction(selectedRowAction: SettingsSelectedRowAction, forRowWithIndex rowIndex: Int, forSectionWithIndex sectionIndex: Int, withSettingsViewModel settingsViewModel: SettingsViewModelProtocol?, tableView: UITableView?, forUIViewController uIViewController: UIViewController) {
            
            switch selectedRowAction {
                
            case let .askText(title, message, keyboardType, text, placeHolder, actionTitle, cancelTitle, actionHandler, cancelHandler, inputValidator):
                
                let alert = UIAlertController(title: title, message: message, keyboardType: keyboardType, text: text, placeHolder: placeHolder, actionTitle: actionTitle, cancelTitle: cancelTitle, actionHandler: { (text:String) in
                    
                    if let inputValidator = inputValidator, let errorMessage = inputValidator(text) {
                        
                        // need to show the error message
                        let alert = UIAlertController(title: Texts_Common.warning, message: errorMessage, actionHandler: nil)
                        
                        uIViewController.present(alert, animated: true, completion: nil)
                        
                    } else {
                        
                        // do the action
                        actionHandler(text)
                        
                    }
                    
                    // check if refresh is needed, either complete settingsview or individual section
                    self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: settingsViewModel, rowIndex: rowIndex, sectionIndex: sectionIndex)
                    
                }, cancelHandler: cancelHandler)
                
                // present the alert
                uIViewController.present(alert, animated: true, completion: nil)
                
            case .nothing:
                break
                
            case let .callFunction(function):
                
                // call function
                function()
                
                // check if refresh is needed, either complete settingsview or individual section
                self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: settingsViewModel, rowIndex: rowIndex, sectionIndex: sectionIndex)
				
			case let .callFunctionAndShareFile(function):
				
				// Start a ProgressBar
				let progressBar = ProgressBarViewController()
				progressBar.start(onParent: uIViewController)
				
				// call function and in the callback handles updating
				// the progress bar and presenting the share file menu.
				// The callback is called multiple times until .complete is true.
				function({ (progress : ProgressBarStatus<URL>?) in
					
					guard let progress = progress else {
						progressBar.end()
						return
					}
					
					// update the loading bar
					// This will destroy the bar if .complete
					progressBar.update(status: progress)
					
					// If URL is not nil and progress is complete, attempt to share the file.
					if let fileURL = progress.data, progress.complete {
						DispatchQueue.main.async {
							// Present the user with a share file menu.
							let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: [])
							uIViewController.present(activityViewController, animated: true)
						}
					}
				})
				
				// check if refresh is needed, either complete settingsview or individual section
				self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: settingsViewModel, rowIndex: rowIndex, sectionIndex: sectionIndex)
				
                
            case let .selectFromList(title, data, selectedRow, actionTitle, cancelTitle, actionHandler, cancelHandler, didSelectRowHandler):
                
                // configure pickerViewData
                let pickerViewData = PickerViewData(withMainTitle: nil, withSubTitle: title, withData: data, selectedRow: selectedRow, withPriority: nil, actionButtonText: actionTitle, cancelButtonText: cancelTitle, onActionClick: {(_ index: Int) in
                    actionHandler(index)
                    
                    // check if refresh is needed, either complete settingsview or individual section
                    self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: settingsViewModel, rowIndex: rowIndex, sectionIndex: sectionIndex)
                    
                }, onCancelClick: {
                    if let cancelHandler = cancelHandler { cancelHandler() }
                }, didSelectRowHandler: {(_ index: Int) in
                    
                    if let didSelectRowHandler = didSelectRowHandler {
                        didSelectRowHandler(index)
                    }
                    
                })
                
                // create and present pickerviewcontroller
                PickerViewControllerModal.displayPickerViewController(pickerViewData: pickerViewData, parentController: uIViewController)
                
                break
                
            case .performSegue(let withIdentifier, let sender):
                uIViewController.performSegue(withIdentifier: withIdentifier, sender: sender)
                
            case let .showInfoText(title, message, actionHandler):
                
                let alert = UIAlertController(title: title, message: message, actionHandler: actionHandler)
                
                uIViewController.present(alert, animated: true, completion: nil)
                
            case let .askConfirmation(title, message, actionHandler, cancelHandler):
                
                // first ask user confirmation
                let alert = UIAlertController(title: title, message: message, actionHandler: {
                    
                    actionHandler()
                    
                    // check if refresh is needed, either complete settingsview or individual section
                    self.checkIfReloadNeededAndReloadIfNeeded(tableView: tableView, viewModel: settingsViewModel, rowIndex: rowIndex, sectionIndex: sectionIndex)
                    
                }, cancelHandler: cancelHandler)
                
                uIViewController.present(alert, animated: true, completion: nil)
                
            }

    }

    // MARK: private helper functions
    
    /// for specified UITableView, viewModel, rowIndex and sectionIndex, check if a refresh of just the section is needed or the complete settings view, and refresh if so
    ///
    /// Changing one setting value, may need hiding or masking or other setting rows. Goal is to minimize the refresh to the section if possible and to avoid refreshing the whole screen as much as possible.
    /// This function will verify if complete reload is needed or not
    /// - parameters:
    ///     - tableView : if nil then no reload will be done, eg M5StackViewController uses these utilites but will not have a viewModel
    ///     - viewModel : if nil then no reload will be done, eg M5StackViewController uses these utilites but will not have a viewModel
    private static func checkIfReloadNeededAndReloadIfNeeded(tableView: UITableView?, viewModel:SettingsViewModelProtocol?, rowIndex:Int, sectionIndex:Int ) {
        
        if let viewModel = viewModel, let tableView = tableView {
            if viewModel.completeSettingsViewRefreshNeeded(index: rowIndex) {
                tableView.reloadSections(IndexSet(integersIn: 0..<tableView.numberOfSections), with: .none)
            } else {
                tableView.reloadSections(IndexSet(integer: sectionIndex), with: .none)
            }
        } else {
            if let tableView = tableView {
                tableView.reloadSections(IndexSet(integer: sectionIndex), with: .none)
            }
        }
    }
    
}
