import SwiftUI

/// to configure loop delays, time + value to use
///
/// see https://medium.com/@max.codes/use-swiftui-in-uikit-view-controllers-with-uihostingcontroller-8fe68dfc523b
final class LoopDelayScheduleViewController: UIViewController {
    
    // will use SwiftUI - UIHostingController allows to use SwiftUi in UIKit project
    let loopDelayScheduleContentView = UIHostingController(rootView: LoopDelayScheduleView())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(loopDelayScheduleContentView)
        view.addSubview(loopDelayScheduleContentView.view)
        
        title = Texts_SettingsView.loopDelaysScreenTitle
            
        setupConstraints()
    }

    private func setupConstraints() {
        loopDelayScheduleContentView.view.translatesAutoresizingMaskIntoConstraints = false
        loopDelayScheduleContentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        loopDelayScheduleContentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        loopDelayScheduleContentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        loopDelayScheduleContentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }

}


