//
//  TableViewController.swift
//  SampleApp
//
//  Created by Nick Lockwood on 22/06/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit
import Layout

let images = [
    UIImage(named: "Boxes"),
    UIImage(named: "Pages"),
    UIImage(named: "Text"),
    UIImage(named: "Table"),
    UIImage(named: "Rocket"),
]

class TableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var tableView: UITableView? {
        didSet {
            tableView?.registerLayout(
                named: "TableCell.xml",
                forCellReuseIdentifier: "cell"
            )
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView?.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 50
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let node = tableView.dequeueReusableLayoutNode(withIdentifier: "cell", for: indexPath)
        node.state = [
            "row": indexPath.row,
            "image": images[indexPath.row % images.count] as Any,
        ]
        return node.view as! UITableViewCell
    }
}
