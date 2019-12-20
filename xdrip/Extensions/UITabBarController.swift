import Foundation
import UIKit

extension UITabBarController {
    func cleanTitles() {
        guard let items = self.tabBar.items else {
            return
        }
        for item in items {
            item.title = ""
            item.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
}
