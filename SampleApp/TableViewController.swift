//  Copyright © 2017 Schibsted. All rights reserved.

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
            tableView?.estimatedRowHeight = 50
            tableView?.estimatedSectionHeaderHeight = 50
            tableView?.registerLayout(
                named: "TableCell.xml",
                forCellReuseIdentifier: "standaloneCell"
            )
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return 50
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let node = tableView.dequeueReusableHeaderFooterNode(withIdentifier: "templateHeader")
        return node?.view as? UITableViewHeaderFooterView
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = (indexPath.row % 2 == 0) ? "templateCell" : "standaloneCell"
        let node = tableView.dequeueReusableCellNode(withIdentifier: identifier, for: indexPath)
        let image = images[indexPath.row % images.count]!

        node.state = [
            "row": indexPath.row,
            "image": image,
            "whiteImage": image.withRenderingMode(.alwaysOriginal),
        ]

        return node.view as! UITableViewCell
    }
}
