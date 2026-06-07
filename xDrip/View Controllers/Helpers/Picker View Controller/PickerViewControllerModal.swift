//
//  PickerViewModalController.swift
//  xdrip
//
//  Created by Paul Plant on 1/3/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import UIKit

class PickerViewControllerModal: UIViewController {
    // MARK: - Lazy views
    
    lazy var pickerViewMainTitle: UILabel = {
        let label = UILabel()
        label.font = ConstantsPickerView.mainTitleFont
        label.textColor = UIColor(resource: .colorPrimary)
        return label
    }()
    
    lazy var pickerViewSubtitle: UILabel = {
        let label = UILabel()
        label.font = ConstantsPickerView.subTitleFont
        label.textColor = UIColor(resource: .colorPrimary)
        return label
    }()
    
    lazy var pickerView: UIPickerView = {
        let pickerView = UIPickerView()
        return pickerView
    }()
    
    lazy var cancelButton: UIButton = {
        var configuration = UIButton.Configuration.gray()
        configuration.title = cancelButtonTitle ?? Texts_Common.Cancel
        configuration.baseForegroundColor = UIColor(resource: .colorPrimary)
        configuration.buttonSize = .medium
        
        let button = UIButton(type: .system, primaryAction: UIAction(handler: { _ in
            if let cancelHandler = self.cancelHandler { cancelHandler() }
            
            // force a state change so that the observer in RVC will pick it up and refresh the snooze icon state
            UserDefaults.standard.updateSnoozeStatus = !UserDefaults.standard.updateSnoozeStatus
        }))
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = configuration
        
        return button
    }()
    
    lazy var addButton: UIButton = {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = addButtonTitle ?? Texts_Common.Ok
        configuration.baseForegroundColor = UIColor(resource: .colorPrimary)
        configuration.baseBackgroundColor = .green
        configuration.buttonSize = .medium
        
        let button = UIButton(type: .system, primaryAction: UIAction(handler: { _ in
            if let selectedIndex = self.selectedRow { self.addHandler(selectedIndex) }
            
            // force a state change so that the observer in RVC will pick it up and refresh the snooze icon state
            UserDefaults.standard.updateSnoozeStatus = !UserDefaults.standard.updateSnoozeStatus
        }))
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = configuration
        
        return button
    }()
    
    lazy var addCancelButtonsStackView: UIStackView = {
        let spacer = UIView()
        let stackView = UIStackView(arrangedSubviews: [cancelButton, spacer, addButton])
        stackView.axis = .horizontal
        return stackView
    }()
    
    lazy var contentStackView: UIStackView = {
        let spacer = UIView()
        let titleStackView = UIStackView(arrangedSubviews: [])
        titleStackView.axis = .vertical
        titleStackView.spacing = 10
        
        if pickerViewMainTitle.text != "" {
            titleStackView.addArrangedSubview(pickerViewMainTitle)
        }
        
        if pickerViewSubtitle.text != "" {
            titleStackView.addArrangedSubview(pickerViewSubtitle)
        }
        
        let stackView = UIStackView(arrangedSubviews: [titleStackView, pickerView, addCancelButtonsStackView, spacer])
        stackView.axis = .vertical
        stackView.spacing = -10
        return stackView
    }()
    
    lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = ConstantsPickerView.containerViewBackgroundColor
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    let maxDimmedAlpha: CGFloat = ConstantsPickerView.maxDimmedAlpha
    lazy var dimmedView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = maxDimmedAlpha
        return view
    }()
    
    // MARK: - Properties
    
    var defaultHeight = ConstantsPickerView.defaultHeight
    let dismissibleHeight = ConstantsPickerView.dismissibleHeight
    
    var currentContainerHeight: CGFloat = ConstantsPickerView.defaultHeight
    
    // Dynamic container constraint
    var containerViewHeightConstraint: NSLayoutConstraint?
    var containerViewBottomConstraint: NSLayoutConstraint?

    /// maintitle to use for pickerview
    var mainTitle: String?
    
    /// subtitle to use for pickerview
    var subTitle: String?
    
    /// will have the soure data in the pickerview
    var dataSource: [String] = []
    
    /// selectedIndex, initial value can be set by parent uiviewcontroller
    var selectedRow: Int?
    
    /// name of button that allows user to select, ie the "Ok" button
    var addButtonTitle: String?
    
    /// name of button that allows user to cancel, ie the "Cancel" button
    var cancelButtonTitle: String?
    
    /// handler to executed when user clicks actionButton
    var addHandler: ((_ index: Int) -> Void) = { _ in fatalError("in PickerViewControllerModal, actionHandler is not initialized") }
    
    /// handler to execute when user clicks cancelHandler
    var cancelHandler: (() -> Void)?
    
    /// will be called when user change selection before clicking ok or cancel button
    var didSelectRowHandler: ((Int) -> Void)?
    
    /// priority to be applied
    private var priority: PickerViewPriority?
    
    // MARK: Overriden functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        
        // tap gesture on dimmed view to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCloseAction))
        dimmedView.addGestureRecognizer(tapGesture)
        
        setupPanGesture()
    }
    
    @objc func handleCloseAction() {
        animateDismissView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateShowDimmedView()
        animatePresentContainer()
    }
    
    func setupView() {
        view.backgroundColor = .clear
        
        pickerView.setValue(UIColor(resource: .colorPrimary), forKey: "textColor")
        pickerView.translatesAutoresizingMaskIntoConstraints = false

        pickerView.dataSource = self
        pickerView.delegate = self
        
        if let selectedRow = selectedRow {
            pickerView.selectRow(selectedRow, inComponent: 0, animated: false)
        }
        
        if let priority = priority {
            switch priority {
            case .normal:
                break
            case .high:
                pickerViewMainTitle.textColor = UIColor.red
            }
        }
    }
    
    // MARK: Setup Constraints
    
    func setupConstraints() {
        // Add subviews
        view.addSubview(dimmedView)
        view.addSubview(containerView)
        dimmedView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(contentStackView)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set static constraints
        NSLayoutConstraint.activate([
            // set dimmedView edges to superview
            dimmedView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // set container static constraint (trailing & leading)
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // content stackView
            contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
        ])
        
        // Set dynamic constraints
        // First, set container to default height
        // after panning, the height can expand
        containerViewHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: defaultHeight)
        
        // By setting the height to default height, the container will be hide below the bottom anchor view
        // Later, will bring it up by set it to 0
        // set the constant to default height to bring it down again
        containerViewBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: defaultHeight)
        // Activate constraints
        containerViewHeightConstraint?.isActive = true
        containerViewBottomConstraint?.isActive = true
    }
    
    func setupPanGesture() {
        // add pan gesture recognizer to the view controller's view (the whole screen)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(gesture:)))
        // change to false to immediately listen on gesture movement
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        view.addGestureRecognizer(panGesture)
    }
    
    // MARK: Pan gesture handler

    @objc func handlePanGesture(gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        // New height is based on value of dragging plus current container height
        let newHeight = currentContainerHeight - translation.y
        
        // Handle based on gesture state
        switch gesture.state {
        case .changed:
            // This state will occur when user is dragging
            if newHeight < defaultHeight {
                // Keep updating the height constraint
                containerViewHeightConstraint?.constant = newHeight
                // refresh layout
                view.layoutIfNeeded()
            }
        case .ended:
            // This happens when user stop drag,
            // so we will get the last height of container
            
            // Condition 1: If new height is below min, dismiss controller
            if newHeight < dismissibleHeight {
                animateDismissView()
            } else {
                animateContainerHeight(defaultHeight)
            }
        default:
            break
        }
    }
    
    func animateContainerHeight(_ height: CGFloat) {
        UIView.animate(withDuration: 0.4) {
            // Update container height
            self.containerViewHeightConstraint?.constant = height
            // Call this to trigger refresh constraint
            self.view.layoutIfNeeded()
        }
        // Save current height
        currentContainerHeight = height
    }
    
    // MARK: Present and dismiss animation

    func animatePresentContainer() {
        // update bottom constraint in animation block
        UIView.animate(withDuration: 0.3) {
            self.containerViewBottomConstraint?.constant = 0
            // call this to trigger refresh constraint
            self.view.layoutIfNeeded()
        }
    }
    
    func animateShowDimmedView() {
        dimmedView.alpha = 0
        UIView.animate(withDuration: 0.4) {
            self.dimmedView.alpha = self.maxDimmedAlpha
        }
    }
    
    func animateDismissView() {
        // hide blur view
        dimmedView.alpha = maxDimmedAlpha
        UIView.animate(withDuration: 0.4) {
            self.dimmedView.alpha = 0
        } completion: { _ in
            // call cancelhandler
            if let cancelHandler = self.cancelHandler {
                cancelHandler()
            } else {
                // once done, dismiss without animation
                self.dismiss(animated: false)
            }
        }
        // hide main view by updating bottom constraint in animation block
        UIView.animate(withDuration: 0.3) {
            self.containerViewBottomConstraint?.constant = self.defaultHeight
            // call this to trigger refresh constraint
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Public Methods
    
    /// creates and presents a new PickerViewControllerModal in the parentController - if there's already another uiviewcontroller being presented by the specified parentController, then the cancelhandler will be called immediately without trying to present anything
    /// - parameters:
    ///     - pickerViewData : data to use in the pickerviewcontroller
    ///     - parentController : the parentController to which the pickerviewcontroller will be added
    public static func displayPickerViewController(pickerViewData: PickerViewData, parentController: UIViewController) {
        let pickerViewController = PickerViewControllerModal()
        pickerViewController.modalPresentationStyle = .overCurrentContext
        
        // change the default height to be smaller if the picker view is displayed over a full-screen view
        // instead of with a navigation controller
        pickerViewController.defaultHeight = pickerViewData.fullScreen ?? false ? ConstantsPickerView.defaultHeightWhenFullScreen : ConstantsPickerView.defaultHeight
        
        // configure pickerViewController
        if pickerViewData.mainTitle != nil {
            pickerViewController.pickerViewMainTitle.text = pickerViewData.mainTitle
        } else {
            pickerViewController.pickerViewMainTitle.text = ""
            pickerViewController.defaultHeight -= 30
        }
        
        if pickerViewData.subTitle != nil {
            pickerViewController.pickerViewSubtitle.text = pickerViewData.subTitle
        } else {
            pickerViewController.pickerViewSubtitle.text = ""
            pickerViewController.defaultHeight -= 25
        }
        
        pickerViewController.currentContainerHeight = pickerViewController.defaultHeight
        
        pickerViewController.addButtonTitle = pickerViewData.actionTitle
        pickerViewController.cancelButtonTitle = pickerViewData.cancelTitle
        
        pickerViewController.dataSource = pickerViewData.data
        pickerViewController.selectedRow = pickerViewData.selectedRow
        pickerViewController.priority = pickerViewData.priority
        
        pickerViewController.addHandler = { (_ index: Int) in
            pickerViewController.dismiss(animated: true, completion: nil)
            pickerViewData.actionHandler(index)
        }
        
        pickerViewController.cancelHandler = {
            pickerViewController.dismiss(animated: true, completion: nil)
            if let cancelHandler = pickerViewData.cancelHandler {
                cancelHandler()
            }
        }
        
        pickerViewController.didSelectRowHandler = pickerViewData.didSelectRowHandler
        parentController.present(pickerViewController, animated: false)
    }
}

extension PickerViewControllerModal: UIPickerViewDelegate {
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

extension PickerViewControllerModal: UIPickerViewDataSource {
    // MARK: - UIPickerViewDataSource protocol Methods
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dataSource.count
    }
}
