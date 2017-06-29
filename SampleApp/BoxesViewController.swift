//
//  BoxesViewController.swift
//  SampleApp
//
//  Created by Nick Lockwood on 13/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

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
