//
//  DatePickerViewControllerModal.swift
//  xdrip
//
//  Created by Paul Plant on 13/3/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import UIKit

class DatePickerViewControllerModal: UIViewController {
    // MARK: - Lazy views
    
    lazy var datePickerViewMainTitle: UILabel = {
        let label = UILabel()
        label.font = ConstantsPickerView.mainTitleFont
        label.textColor = UIColor(resource: .colorPrimary)
        return label
    }()
    
    lazy var datePickerViewSubtitle: UILabel = {
        let label = UILabel()
        label.font = ConstantsPickerView.subTitleFont
        label.textColor = UIColor(resource: .colorPrimary)
        return label
    }()
    
    lazy var datePickerView: UIDatePicker = {
        let datePickerView = UIDatePicker()
        datePickerView.preferredDatePickerStyle = .wheels
        return datePickerView
    }()
    
    lazy var cancelButton: UIButton = {
        var configuration = UIButton.Configuration.gray()
        configuration.title = cancelButtonTitle ?? Texts_Common.Cancel
        configuration.baseForegroundColor = UIColor(resource: .colorPrimary)
        configuration.buttonSize = .medium
        
        let button = UIButton(type: .system, primaryAction: UIAction(handler: { _ in
            if let cancelHandler = self.cancelHandler { cancelHandler() }
        }))
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = configuration
        
        return button
    }()
    
    lazy var okButton: UIButton = {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = addButtonTitle ?? Texts_Common.Ok
        configuration.baseForegroundColor = UIColor(resource: .colorPrimary)
        configuration.baseBackgroundColor = .green
        configuration.buttonSize = .medium
        
        let button = UIButton(type: .system, primaryAction: UIAction(handler: { _ in
            self.okHandler(self.datePickerView.date)
        }))
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = configuration
        
        return button
    }()
    
    lazy var addCancelButtonsStackView: UIStackView = {
        let spacer = UIView()
        let stackView = UIStackView(arrangedSubviews: [cancelButton, spacer, okButton])
        stackView.axis = .horizontal
        return stackView
    }()
    
    lazy var contentStackView: UIStackView = {
        let spacer = UIView()
        let titleStackView = UIStackView(arrangedSubviews: [])
        titleStackView.axis = .vertical
        titleStackView.spacing = 10
        
        if datePickerViewMainTitle.text != "" {
            titleStackView.addArrangedSubview(datePickerViewMainTitle)
        }
        
        if datePickerViewSubtitle.text != "" {
            titleStackView.addArrangedSubview(datePickerViewSubtitle)
        }
        
        let stackView = UIStackView(arrangedSubviews: [titleStackView, datePickerView, addCancelButtonsStackView, spacer])
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
    
    /// name of button that allows user to select, ie the "Ok" button
    var addButtonTitle: String?
    
    /// name of button that allows user to cancel, ie the "Cancel" button
    var cancelButtonTitle: String?
    
    /// handler to executed when user clicks actionButton
    var okHandler: ((_ date: Date) -> Void) = { _ in fatalError("in DatePickerViewControllerModal, okHandler is not initialized") }
    
    /// handler to execute when user clicks cancelHandler
    var cancelHandler: (() -> Void)?
    
    /// default date to set
    var date: Date?
    
    /// if minimumDate defined
    var minimumDate: Date?
    
    /// if maximumDate defined
    var maximumDate: Date?
    
    /// datepickermode
    var datePickerMode: UIDatePicker.Mode?
    
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateShowDimmedView()
        animatePresentContainer()
    }
    
    @objc func handleCloseAction() {
        animateDismissView()
    }
    
    func setupView() {
        view.backgroundColor = .clear
        
        datePickerView.setValue(UIColor(resource: .colorPrimary), forKey: "textColor")
        datePickerView.translatesAutoresizingMaskIntoConstraints = false
        
        if let date = date { datePickerView.setDate(date, animated: true) }
        
        if let datePickerMode = datePickerMode { datePickerView.datePickerMode = datePickerMode }
        
        if let maximumDate = maximumDate { datePickerView.maximumDate = maximumDate }
        
        if let minimumDate = minimumDate { datePickerView.minimumDate = minimumDate }
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
    
    /// creates and presents a new DatePickerViewControllerModal in the parentController - if there's already another uiviewcontroller being presented by the specified parentController, then the cancelhandler will be called immediately without trying to present anything
    /// - parameters:
    ///     - datePickerViewData : data to use in the datePickerViewController
    ///     - parentController : the parentController to which the pickerviewcontroller will be added
    public static func displayDatePickerViewController(datePickerViewData: DatePickerViewData, parentController: UIViewController) {
        let datePickerViewController = DatePickerViewControllerModal()
        datePickerViewController.modalPresentationStyle = .overCurrentContext
        
        // change the default height to be smaller if the picker view is displayed over a full-screen view
        // instead of with a navigation controller
        datePickerViewController.defaultHeight = datePickerViewData.fullScreen ?? false ? ConstantsPickerView.defaultHeightWhenFullScreen : ConstantsPickerView.defaultHeight
        
        // configure pickerViewController
        if datePickerViewData.mainTitle != nil {
            datePickerViewController.datePickerViewMainTitle.text = datePickerViewData.mainTitle
        } else {
            datePickerViewController.datePickerViewMainTitle.text = ""
            datePickerViewController.defaultHeight -= 30
        }
        
        if datePickerViewData.subTitle != nil {
            datePickerViewController.datePickerViewSubtitle.text = datePickerViewData.subTitle
        } else {
            datePickerViewController.datePickerViewSubtitle.text = ""
            datePickerViewController.defaultHeight -= 25
        }
        
        datePickerViewController.currentContainerHeight = datePickerViewController.defaultHeight
        
        datePickerViewController.addButtonTitle = datePickerViewData.okTitle
        datePickerViewController.cancelButtonTitle = datePickerViewData.cancelTitle
        
        datePickerViewController.date = datePickerViewData.date
        datePickerViewController.datePickerMode = datePickerViewData.datePickerMode
        datePickerViewController.minimumDate = datePickerViewData.minimumDate
        datePickerViewController.maximumDate = datePickerViewData.maximumDate
        
        if datePickerViewController.datePickerMode == .time {
            datePickerViewController.datePickerView.minuteInterval = 10
        }
        
        datePickerViewController.okHandler = { (_ date: Date) in
            datePickerViewController.dismiss(animated: true, completion: nil)
            datePickerViewData.okHandler(date)
        }
        
        datePickerViewController.cancelHandler = {
            datePickerViewController.dismiss(animated: true, completion: nil)
            if let cancelHandler = datePickerViewData.cancelHandler { cancelHandler() }
        }
        
        parentController.present(datePickerViewController, animated: false)
    }
}
