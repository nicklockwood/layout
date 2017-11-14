//
//  TableCell.swift
//  Layout
//
//  Created by Mukesh Murali on 14/11/17.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

class TableCell: UITableViewCell {
    @IBOutlet var button: UIButton?;
    
    @IBAction func buttonClicked() {
        button?.backgroundColor = UIColor.blue // Used for showcasing how to reference Prefer changing values using setState.
        self.layoutNode?.setState(["buttonText": "Clicked"])
    }

}
