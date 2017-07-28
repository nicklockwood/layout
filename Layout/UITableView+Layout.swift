//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

private let tableViewStyle = RuntimeType(UITableViewStyle.self, [
    "plain": .plain,
    "grouped": .grouped,
])

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
        let hadView = (node._view != nil)
        switch node.viewClass {
        case is UITableViewCell.Type:
            // TODO: it would be better if we never added cell template nodes to
            // the hierarchy, rather than having to remove them afterwards
            node.removeFromParent()
            if let expression = node.expressions["reuseIdentifier"] {
                let idExpression = LayoutExpression(
                    expression: expression,
                    type: RuntimeType(String.self),
                    for: node
                )
                if let reuseIdentifier = try? idExpression.evaluate() as! String {
                    registerLayout(Layout(node), forCellReuseIdentifier: reuseIdentifier)
                }
            } else {
                print("UITableViewCell template missing reuseIdentifier")
            }
        case is UITableViewHeaderFooterView.Type:
            node.removeFromParent()
            if let expression = node.expressions["reuseIdentifier"] {
                let idExpression = LayoutExpression(
                    expression: expression,
                    type: RuntimeType(String.self),
                    for: node
                )
                if let reuseIdentifier = try? idExpression.evaluate() as! String {
                    registerLayout(Layout(node), forHeaderFooterViewReuseIdentifier: reuseIdentifier)
                }
            } else {
                print("UITableViewHeaderFooterView template missing reuseIdentifier")
            }
        default:
            if tableHeaderView == nil {
                tableHeaderView = node.view
            } else if tableFooterView == nil {
                tableFooterView = node.view
            } else {
                super.didInsertChildNode(node, at: index)
            }
            return
        }
        // Check we didn't accidentally instantiate the view
        assert(hadView || node._view == nil)
    }

    open override func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        let hadView = (node._view != nil)
        super.willRemoveChildNode(node, at: index)
        if node._view == tableHeaderView {
            tableHeaderView = nil
        } else if node._view == tableFooterView {
            tableFooterView = nil
        }
        // Check we didn't accidentally instantiate the view
        assert(hadView || node._view == nil)
    }
}

private var rowDataKey = 0
private var headerDataKey = 0
private var nodesKey = 0

extension UITableView: LayoutDelegate {

    private enum LayoutData {
        case success(Layout, Any, [String: Any])
        case failure(Error)
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

    // MARK: UITableViewHeaderFooterView recycling

    private func registerLayoutData(
        _ layoutData: LayoutData,
        forHeaderFooterViewReuseIdentifier identifier: String
    ) {
        var layoutsData = objc_getAssociatedObject(self, &headerDataKey) as? NSMutableDictionary
        if layoutsData == nil {
            layoutsData = [:]
            objc_setAssociatedObject(self, &headerDataKey, layoutsData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        layoutsData![identifier] = layoutData
    }

    fileprivate func registerLayout(
        _ layout: Layout,
        state: Any = (),
        constants: [String: Any]...,
        forHeaderFooterViewReuseIdentifier identifier: String
    ) {
        registerLayoutData(
            .success(layout, state, merge(constants)),
            forHeaderFooterViewReuseIdentifier: identifier
        )
    }

    public func registerLayout(
        named: String,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file,
        state: Any = (),
        constants: [String: Any]...,
        forHeaderFooterViewReuseIdentifier identifier: String
    ) {
        do {
            let layout = try LayoutLoader().loadLayout(
                named: named,
                bundle: bundle,
                relativeTo: relativeTo
            )
            registerLayout(
                layout,
                state: state,
                constants: merge(constants),
                forHeaderFooterViewReuseIdentifier: identifier
            )
        } catch {
            registerLayoutData(.failure(error), forCellReuseIdentifier: identifier)
        }
    }

    public func dequeueReusableHeaderFooterNode(withIdentifier identifier: String) -> LayoutNode? {
        if let view = dequeueReusableHeaderFooterView(withIdentifier: identifier) {
            guard let node = view.layoutNode else {
                preconditionFailure("\(type(of: view)) is not a Layout-managed view")
            }
            return node
        }
        guard let layoutsData = objc_getAssociatedObject(self, &headerDataKey) as? NSMutableDictionary,
            let layoutData = layoutsData[identifier] as? LayoutData else {
            return nil
        }
        var nodes = objc_getAssociatedObject(self, &nodesKey) as? NSMutableArray
        if nodes == nil {
            nodes = []
            objc_setAssociatedObject(self, &nodesKey, nodes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        do {
            switch layoutData {
            case let .success(layout, state, constants):
                let node = try LayoutNode(
                    layout: layout,
                    state: state,
                    constants: constants
                )
                node.delegate = self
                nodes?.add(node)
                node.view.setValue(identifier, forKey: "reuseIdentifier")
                return node
            case let .failure(error):
                throw error
            }
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
            return nil
        }
    }

    // MARK: UITableViewCell recycling

    private func registerLayoutData(
        _ layoutData: LayoutData,
        forCellReuseIdentifier identifier: String
    ) {
        var layoutsData = objc_getAssociatedObject(self, &rowDataKey) as? NSMutableDictionary
        if layoutsData == nil {
            layoutsData = [:]
            objc_setAssociatedObject(self, &rowDataKey, layoutsData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        layoutsData![identifier] = layoutData
    }

    fileprivate func registerLayout(
        _ layout: Layout,
        state: Any = (),
        constants: [String: Any]...,
        forCellReuseIdentifier identifier: String
    ) {
        registerLayoutData(.success(layout, state, merge(constants)), forCellReuseIdentifier: identifier)
    }

    public func registerLayout(
        named: String,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file,
        state: Any = (),
        constants: [String: Any]...,
        forCellReuseIdentifier identifier: String
    ) {
        do {
            let layout = try LayoutLoader().loadLayout(
                named: named,
                bundle: bundle,
                relativeTo: relativeTo
            )
            registerLayout(
                layout,
                state: state,
                constants: merge(constants),
                forCellReuseIdentifier: identifier
            )
        } catch {
            registerLayoutData(.failure(error), forCellReuseIdentifier: identifier)
        }
    }

    public func dequeueReusableCellNode(withIdentifier identifier: String) -> LayoutNode? {
        if let cell = dequeueReusableCell(withIdentifier: identifier) {
            guard let node = cell.layoutNode else {
                preconditionFailure("\(type(of: cell)) is not a Layout-managed view")
            }
            return node
        }
        guard let layoutsData = objc_getAssociatedObject(self, &rowDataKey) as? NSMutableDictionary,
            let layoutData = layoutsData[identifier] as? LayoutData else {
            return nil
        }
        var nodes = objc_getAssociatedObject(self, &nodesKey) as? NSMutableArray
        if nodes == nil {
            nodes = []
            objc_setAssociatedObject(self, &nodesKey, nodes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        do {
            switch layoutData {
            case let .success(layout, state, constants):
                let node = try LayoutNode(
                    layout: layout,
                    state: state,
                    constants: constants
                )
                node.delegate = self
                nodes?.add(node)
                node.view.setValue(identifier, forKey: "reuseIdentifier")
                return node
            case let .failure(error):
                throw error
            }
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
            return nil
        }
    }

    public func dequeueReusableCellNode(withIdentifier identifier: String, for _: IndexPath) -> LayoutNode {
        guard let node = dequeueReusableCellNode(withIdentifier: identifier) else {
            let layoutsData = objc_getAssociatedObject(self, &rowDataKey) as? NSMutableDictionary
            if layoutsData?[identifier] == nil {
                let error = LayoutError.message("No Table cell layout has been registered for `\(identifier)`")
                var responder: UIResponder? = self
                while responder != nil {
                    if let errorHandler = responder as? LayoutLoading {
                        errorHandler.layoutError(LayoutError(error))
                        return LayoutNode(view: UITableViewCell())
                    }
                    responder = responder?.next
                }
                print("Layout error: \(error)")
            }
            return LayoutNode(view: UITableViewCell())
        }
        return node
    }

    @available(*, deprecated, renamed: "dequeueReusableCellNode(withIdentifier:for:)")
    public func dequeueReusableLayoutNode(withIdentifier identifier: String, for indexPath: IndexPath) -> LayoutNode {
        return dequeueReusableCellNode(withIdentifier: identifier, for: indexPath)
    }
}

private let tableViewCellStyle = RuntimeType(UITableViewCellStyle.self, [
    "default": .default,
    "value1": .value1,
    "value2": .value2,
    "subtitle": .subtitle,
])

private var layoutNodeKey = 0

private class Box {
    weak var node: LayoutNode?
    init(_ node: LayoutNode) {
        self.node = node
    }
}

extension UITableViewHeaderFooterView {
    public var layoutNode: LayoutNode? {
        return (objc_getAssociatedObject(self, &layoutNodeKey) as? Box)?.node
    }

    open override class func create(with node: LayoutNode) throws -> UIView {
        var reuseIdentifier: String?
        if let expression = node.expressions["reuseIdentifier"] {
            let idExpression = LayoutExpression(expression: expression, type: RuntimeType(String.self), for: node)
            reuseIdentifier = try idExpression.evaluate() as? String
        }
        let cell = UITableViewHeaderFooterView(reuseIdentifier: reuseIdentifier)
        if node.expressions.keys.contains(where: { $0.hasPrefix("backgroundView.") }),
            !node.expressions.keys.contains("backgroundView") {
            // Add a background view if required
            cell.backgroundView = UIView(frame: cell.bounds)
        }
        objc_setAssociatedObject(cell, &layoutNodeKey, Box(node), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return cell
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["reuseIdentifier"] = RuntimeType(String.self)
        types["editingAccessoryType"] = types["accessoryType"]
        for (key, type) in UIView.expressionTypes {
            types["contentView.\(key)"] = type
            types["backgroundView.\(key)"] = type
        }
        for (key, type) in UILabel.expressionTypes {
            types["textLabel.\(key)"] = type
            types["detailTextLabel.\(key)"] = type
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "reuseIdentifier":
            break // Ignore this - we set it during creation
        case "backgroundColor":
            throw LayoutError.message("Setting `backgroundColor` on UITableViewHeaderFooterView is not supported. Use `contentView.backgroundColor` instead.")
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

    open override var intrinsicContentSize: CGSize {
        guard let layoutNode = layoutNode, layoutNode.children.isEmpty else {
            return super.intrinsicContentSize
        }
        return CGSize(
            width: UIViewNoIntrinsicMetric,
            height: textLabel?.intrinsicContentSize.height ?? UIViewNoIntrinsicMetric
        )
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        if let layoutNode = layoutNode {
            let height = (try? layoutNode.doubleValue(forSymbol: "height")) ?? 0
            return CGSize(width: size.width, height: CGFloat(height))
        }
        return super.sizeThatFits(size)
    }
}

extension UITableViewCell {
    public var layoutNode: LayoutNode? {
        return (objc_getAssociatedObject(self, &layoutNodeKey) as? Box)?.node
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
        if node.expressions.keys.contains(where: { $0.hasPrefix("backgroundView.") }),
            !node.expressions.keys.contains("backgroundView") {
            // Add a backgroundView view if required
            cell.backgroundView = UIView(frame: cell.bounds)
        }
        if node.expressions.keys.contains(where: { $0.hasPrefix("selectedBackgroundView.") }),
            !node.expressions.keys.contains("selectedBackgroundView") {
            // Add a selectedBackground view if required
            cell.selectedBackgroundView = UIView(frame: cell.bounds)
        }
        objc_setAssociatedObject(cell, &layoutNodeKey, Box(node), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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
        for (key, type) in UIView.expressionTypes {
            types["contentView.\(key)"] = type
            types["backgroundView.\(key)"] = type
            types["selectedBackgroundView.\(key)"] = type
        }
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

    open override var intrinsicContentSize: CGSize {
        guard let layoutNode = layoutNode, layoutNode.children.isEmpty else {
            return super.intrinsicContentSize
        }
        return CGSize(width: UIViewNoIntrinsicMetric, height: 44)
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        if let layoutNode = layoutNode {
            let height = (try? layoutNode.doubleValue(forSymbol: "height")) ?? 0
            return CGSize(width: size.width, height: CGFloat(height))
        }
        return super.sizeThatFits(size)
    }
}
