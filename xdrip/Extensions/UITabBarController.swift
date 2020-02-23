import Foundation
import UIKit

extension UITabBarController {
    func cleanTitles() {
        guard let items = self.tabBar.items else {
            return
        }
        for item in items {
            
            // show titles in Tab Bar items - in other words, don't clean them!
            // it's easier to set globally here instead of removing each call
            item.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
}
