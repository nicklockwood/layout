//
//  NorthstarViewController.swift
//  SampleApp
//
//  Created by Nick Lockwood on 10/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit
import Layout
import Northstar

class NorthstarExampleViewController: UIViewController {

    var numberField: NorthstarTextField!
    var termsCheckbox: NorthstarCheckboxControl!
    var privacyCheckbox: NorthstarCheckboxControl!

    var layoutNode: LayoutNode? {
        didSet {
            layoutNode?.state = [
                "hideError": true,
                "error": ""
            ]
        }
    }

    func dismissKeyboard() {
        numberField.resignFirstResponder()
    }

    func submit() {
        numberField.resignFirstResponder()

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
            self.layoutNode?.state = [
                "hideError": error.isEmpty,
                "error": error.trimmingCharacters(in: .newlines)
            ]
        }
    }
}
