//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

private let tableViewStyle = RuntimeType(UITableViewStyle.self, [
    "plain": .plain,
    "grouped": .grouped,
])

private var nodeDataKey = 0
private var nodesKey = 0

extension UITableView {
    open override class func create(with node: LayoutNode) throws -> UIView {
        var style = UITableViewStyle.plain
        if let expression = node.expressions["style"] {
            let styleExpression = LayoutExpression(expression: expression, type: tableViewStyle, for: node)
            style = try styleExpression.evaluate() as! UITableViewStyle
        }
        let view = UITableView(frame: .zero, style: style)
        view.rowHeight = UITableViewAutomaticDimension
        return view
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["style"] = tableViewStyle
        types["separatorStyle"] = RuntimeType(UITableViewCellSeparatorStyle.self, [
            "none": .none,
            "singleLine": .singleLine,
            "singleLineEtched": .singleLineEtched,
        ])
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "style":
            break // Ignore this - we set it during creation
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        guard let _ = node.view as? UITableViewCell else {
            super.didInsertChildNode(node, at: index)
            return
        }
        preconditionFailure("Inserting UITableViewCells directly in xml is not supported")
    }

    private class LayoutData {
        let name: String
        let bundle: Bundle
        let relativeTo: String
        let state: Any
        let constants: [String: Any]
        init(name: String, bundle: Bundle, relativeTo: String, state: Any, constants: [String: Any]) {
            self.name = name
            self.bundle = bundle
            self.relativeTo = relativeTo
            self.state = state
            self.constants = constants
        }
    }

    private func merge(_ dictionaries: [[String: Any]]) -> [String: Any] {
        var result = [String: Any]()
        for dict in dictionaries {
            for (key, value) in dict {
                result[key] = value
            }
        }
        return result
    }

    public func registerLayout(
        named: String,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file,
        state: Any = (),
        constants: [String: Any]...,
        forCellReuseIdentifier identifier: String
    ) {
        var xmlData = objc_getAssociatedObject(self, &nodeDataKey) as? NSMutableDictionary
        if xmlData == nil {
            xmlData = [:]
            objc_setAssociatedObject(self, &nodeDataKey, xmlData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        xmlData?[identifier] = LayoutData(
            name: named,
            bundle: bundle,
            relativeTo: relativeTo,
            state: state,
            constants: merge(constants)
        )
    }

    public func dequeueReusableLayoutNode(withIdentifier identifier: String, for _: IndexPath) -> LayoutNode {
        if let cell = dequeueReusableCell(withIdentifier: identifier) {
            guard let node = cell.layoutNode else {
                preconditionFailure("\(type(of: cell)) is not a Layout-managed view")
            }
            node.view.translatesAutoresizingMaskIntoConstraints = (rowHeight != UITableViewAutomaticDimension)
            return node
        }
        guard let xmlData = objc_getAssociatedObject(self, &nodeDataKey) as? NSMutableDictionary,
            let layoutData = xmlData[identifier] as? LayoutData else {
            preconditionFailure("No Layout XML has been registered for `identifier`")
        }
        var nodes = objc_getAssociatedObject(self, &nodesKey) as? NSMutableArray
        if nodes == nil {
            nodes = []
            objc_setAssociatedObject(self, &nodesKey, nodes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        do {
            let node = try LayoutLoader().loadLayout(
                named: layoutData.name,
                bundle: layoutData.bundle,
                relativeTo: layoutData.relativeTo,
                state: layoutData.state,
                constants: layoutData.constants
            )
            nodes?.add(node)
            node.view.setValue(identifier, forKey: "reuseIdentifier")
            node.view.translatesAutoresizingMaskIntoConstraints = (rowHeight != UITableViewAutomaticDimension)
            return node
        } catch {
            var responder: UIResponder? = self
            while responder != nil {
                if let errorHandler = responder as? LayoutLoading {
                    errorHandler.layoutError(LayoutError(error))
                    return LayoutNode(view: UITableViewCell())
                }
                responder = responder?.next
            }
            print("Layout error: \(error)")
            return LayoutNode(view: UITableViewCell())
        }
    }
}

private let tableViewCellStyle = RuntimeType(UITableViewCellStyle.self, [
    "default": .default,
    "value1": .value1,
    "value2": .value2,
    "subtitle": .subtitle,
])

private var cellNodeKey = 0

extension UITableViewCell {
    private class Box {
        weak var node: LayoutNode?
        init(_ node: LayoutNode) {
            self.node = node
        }
    }

    public var layoutNode: LayoutNode? {
        return (objc_getAssociatedObject(self, &cellNodeKey) as? Box)?.node
    }

    open override class func create(with node: LayoutNode) throws -> UIView {
        var style = UITableViewCellStyle.default
        if let expression = node.expressions["style"] {
            let styleExpression = LayoutExpression(expression: expression, type: tableViewCellStyle, for: node)
            style = try styleExpression.evaluate() as! UITableViewCellStyle
        }
        var reuseIdentifier: String?
        if let expression = node.expressions["reuseIdentifier"] {
            let idExpression = LayoutExpression(expression: expression, type: RuntimeType(String.self), for: node)
            reuseIdentifier = try idExpression.evaluate() as? String
        }
        let cell = UITableViewCell(style: style, reuseIdentifier: reuseIdentifier)
        objc_setAssociatedObject(cell, &cellNodeKey, Box(node), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return cell
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["style"] = tableViewCellStyle
        types["reuseIdentifier"] = RuntimeType(String.self)
        types["selectionStyle"] = RuntimeType(UITableViewCellSelectionStyle.self, [
            "none": .none,
            "blue": .blue,
            "gray": .gray,
            "default": .default,
        ])
        types["focusStyle"] = RuntimeType(UITableViewCellFocusStyle.self, [
            "default": .default,
            "custom": .custom,
        ])
        types["accessoryType"] = RuntimeType(UITableViewCellAccessoryType.self, [
            "none": .none,
            "disclosureIndicator": .disclosureIndicator,
            "detailDisclosureButton": .detailDisclosureButton,
            "checkmark": .checkmark,
            "detailButton": .detailButton,
        ])
        types["editingAccessoryType"] = types["accessoryType"]
        for (key, type) in UIImageView.expressionTypes {
            types["imageView.\(key)"] = type
        }
        for (key, type) in UILabel.expressionTypes {
            types["textLabel.\(key)"] = type
            types["detailTextLabel.\(key)"] = type
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "style", "reuseIdentifier":
            break // Ignore this - we set it during creation
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = self.viewController {
            for controller in node.viewControllers {
                viewController.addChildViewController(controller)
            }
        }
        // Insert child views into `contentView` instead of directly
        contentView.insertSubview(node.view, at: index)
    }
}
