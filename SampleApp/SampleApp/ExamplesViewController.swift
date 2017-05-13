//
//  ExamplesViewController.swift
//  SampleApp
//
//  Created by Nick Lockwood on 05/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit
import Layout
import Northstar

class ExamplesViewController: LayoutViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        loadLayout(
            named: "Examples.xml",
            constants: [
                // Used in text example
                "attributedString": NSAttributedString(
                    string: "attributed string",
                    attributes: [NSForegroundColorAttributeName: UIColor.red]
                )
            ]
        )
    }
}
