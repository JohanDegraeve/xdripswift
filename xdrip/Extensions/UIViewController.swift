import Foundation
import UIKit

extension UIViewController {
    // MARK: - Static Properties
    
    static var storyboardIdentifier: String {
        return String(describing: self)
    }
}
