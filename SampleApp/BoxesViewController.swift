//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import Layout

class BoxesViewController: UIViewController {

    var toggled = false

    var layoutNode: LayoutNode? {
        didSet {
            layoutNode?.state = ["toggleLayout": toggled]
        }
    }

    func toggle() {
        toggled = !toggled
        UIView.animate(withDuration: 0.4) {
            self.layoutNode?.state = ["toggleLayout": self.toggled]
        }
    }
}
