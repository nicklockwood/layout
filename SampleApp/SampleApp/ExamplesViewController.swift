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

class ExamplesViewController: LayoutViewController, UIScrollViewDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        loadLayout(
            named: "Examples.xml",
            state: [
                "toggleLayout": false, // Boxes state
                "hideError": true, "error": "" // Northstar state
            ],
            constants: [
                "attributedString": NSAttributedString(
                    string: "attributed string",
                    attributes: [NSForegroundColorAttributeName: UIColor.red]
                )
            ]
        )
    }

    // MARK: Boxes

    var boxesExampleNode: LayoutNode!
    var toggled = false

    func toggle() {
        toggled = !toggled
        UIView.animate(withDuration: 0.4) {
            self.boxesExampleNode.state = ["toggleLayout": self.toggled]
        }
    }

    // MARK: Pages

    var scrollView: UIScrollView!
    var pageControl: UIPageControl!

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.scrollView {
            pageControl.currentPage = Int(round(scrollView.contentOffset.x / scrollView.frame.width))
        }
    }

    // MARK: Northstar

    var northstarExampleNode: LayoutNode!
    var numberField: NorthstarTextField!
    var termsCheckbox: NorthstarCheckboxControl!
    var privacyCheckbox: NorthstarCheckboxControl!

    func submit() {
        var error = ""
        if (numberField.text ?? "").isEmpty {
            error += "Please enter your phone number\n"
        }
        if !termsCheckbox.isSelected {
            error += "Please accept the terms and conditions\n"
        }
        if !privacyCheckbox.isSelected {
            error += "Please accept the privacy policy\n"
        }
        UIView.animate(withDuration: 0.4) {
            self.northstarExampleNode.state = [
                "hideError": error.isEmpty,
                "error": error.trimmingCharacters(in: .newlines)
            ]
        }
    }

}
