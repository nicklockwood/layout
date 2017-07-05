//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import Layout

class BoxesViewController: UIViewController {

    var toggled = false {
        didSet {
            layoutNode?.state = ["isToggled": toggled]
        }
    }

    var layoutNode: LayoutNode? {
        didSet {
            layoutNode?.state = ["isToggled": toggled]
        }
    }

    func setToggled() {
        UIView.animate(withDuration: 0.4) {
            self.toggled = true
        }
    }

    func setUntoggled() {
        UIView.animate(withDuration: 0.4) {
            self.toggled = false
        }
    }
}
