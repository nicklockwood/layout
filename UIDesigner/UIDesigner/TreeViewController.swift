//
//  TreeViewController.swift
//  UIDesigner
//
//  Created by Nick Lockwood on 07/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit
import Layout

class TreeViewController: UITableViewController {

    func nodeName(_ node: LayoutNode) -> String {
        return node.viewController.map {
            var name = "\(type(of: $0))"
            if let title = $0.title, !title.isEmpty {
                name += " (\(title))"
            }
            return name
        } ?? "\(type(of: node.view))"
    }

    var layoutNode: LayoutNode? {
        didSet {
            tableView.reloadData()
            if layoutNode?.parent != nil {
                title = nodeName(layoutNode!)
            } else {
                title = "Root"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return layoutNode?.children.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if let layoutNode = layoutNode, layoutNode.children.count > indexPath.row {
            cell.textLabel?.text = nodeName(layoutNode.children[indexPath.row])
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let layoutNode = layoutNode, layoutNode.children.count > indexPath.row else {
            return
        }
        let node = layoutNode.children[indexPath.row]

        if !node.children.isEmpty {
            let controller = TreeViewController()
            controller.layoutNode = node
            navigationController?.pushViewController(controller, animated: true)
        }

        if let designViewController = splitViewController?.viewControllers[1] as? DesignViewController {
            designViewController.selectedNode = node
            designViewController.editNode()
        }
    }
}
