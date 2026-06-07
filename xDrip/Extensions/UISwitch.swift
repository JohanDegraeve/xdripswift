import UIKit

extension UISwitch {
    
    /// creates a UISwitch with initial value isOn, and if user changes the switch status, then runs the closure - calls self.init(frame: CGRect.zero)
    convenience init(isOn:Bool, action:@escaping (Bool) -> Void) {
        self.init(frame: CGRect.zero)
        // set on or off value
        setOn(isOn, animated: true)
        
        // add action when user cliks the UISwitch
        addTarget(self, action: {(theSwitch:UISwitch) in action(theSwitch.isOn)}, for: UIControl.Event.valueChanged)

    }
}
