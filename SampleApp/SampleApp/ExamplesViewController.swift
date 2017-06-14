//
//  ExamplesViewController.swift
//  SampleApp
//
//  Created by Nick Lockwood on 05/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit
import Layout

class ExamplesViewController: LayoutViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        loadLayout(
            named: "Examples.xml",
            constants: [
                // Used in boxes example
                "colors": [
                    "red": UIColor(hexString: "#f66"),
                    "orange": UIColor(hexString: "#fa7"),
                    "blue": UIColor(hexString: "#09f"),
                    "green": UIColor(hexString: "#0f9"),
                    "pink": UIColor(hexString: "#fcc"),
                ],
                // Used in text example
                "attributedString": NSAttributedString(
                    string: "attributed string",
                    attributes: [NSForegroundColorAttributeName: UIColor.red]
                )
            ]
        )
    }
}
