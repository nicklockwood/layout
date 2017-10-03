//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

private let tableViewStyle = RuntimeType(UITableViewStyle.self, [
    "plain": .plain,
    "grouped": .grouped,
] as [String: UITableViewStyle])

private var layoutNodeKey = 0

private class Box {
    weak var node: LayoutNode?
    init(_ node: LayoutNode) {
        self.node = node
    }
}

extension UITableView {
    fileprivate weak var layoutNode: LayoutNode? {
        return (objc_getAssociatedObject(self, &layoutNodeKey) as? Box)?.node
    }

    open override class func create(with node: LayoutNode) throws -> UITableView {
        let style = try node.value(forExpression: "style") as? UITableViewStyle ?? .plain
        let tableView = self.init(frame: .zero, style: style)
        tableView.enableAutoSizing()
        objc_setAssociatedObject(tableView, &layoutNodeKey, Box(node), .OBJC_ASSOCIATION_RETAIN)
        return tableView
    }

    fileprivate func enableAutoSizing() {
        estimatedRowHeight = 44
        rowHeight = UITableViewAutomaticDimension
        estimatedSectionHeaderHeight = 0
        sectionHeaderHeight = UITableViewAutomaticDimension
        estimatedSectionFooterHeight = 0
        sectionFooterHeight = UITableViewAutomaticDimension
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return [
            "style": tableViewStyle,
        ]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["separatorStyle"] = RuntimeType(UITableViewCellSeparatorStyle.self, [
            "none": .none,
            "singleLine": .singleLine,
            "singleLineEtched": .singleLineEtched,
        ] as [String: UITableViewCellSeparatorStyle])
        for name in [
            "contentSize",
            "contentSize.height",
            "contentSize.width",
        ] {
            types[name] = .unavailable()
        }

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "countStringInsignificantRowCount",
                "currentTouch",
                "indexHiddenForSearch",
                "multiselectCheckmarkColor",
                "overlapsSectionHeaderViews",
                "sectionBorderColor",
                "separatorBottomShadowColor",
                "separatorTopShadowColor",
                "tableHeaderBackgroundColor",
                "usesVariableMargins",
            ] {
                types[name] = nil
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif
        return types
    }

    open override func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "isEditing":
            setEditing(value as! Bool, animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        let hadView = (node._view != nil)
        var isCell = false
        switch node.viewClass {
        case is UITableViewCell.Type:
            isCell = true
            fallthrough
        case is UITableViewHeaderFooterView.Type:
            // TODO: it would be better if we never added cell template nodes to
            // the hierarchy, rather than having to remove them afterwards
            node.removeFromParent()
            do {
                if let reuseIdentifier = try node.value(forExpression: "reuseIdentifier") as? String {
                    if isCell {
                        registerLayout(Layout(node), forReuseIdentifier: reuseIdentifier, key: &cellDataKey)
                    } else {
                        registerLayout(Layout(node), forReuseIdentifier: reuseIdentifier, key: &headerDataKey)
                    }
                } else {
                    let viewType = isCell ? "UITableViewCell" : "UITableViewHeaderFooterView"
                    layoutError(.message("\(viewType) template missing reuseIdentifier"))
                }
            } catch {
                layoutError(LayoutError(error))
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
        // TODO: it would be better to do this in a unit test
        assert(hadView || node._view == nil)
    }

    open override func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        let hadView = (node._view != nil)
        super.willRemoveChildNode(node, at: index)
        guard let view = node._view else { return }
        // Check we didn't accidentally instantiate the view
        // TODO: it would be better to do this in a unit test
        assert(hadView)
        if view == tableHeaderView {
            tableHeaderView = nil
        } else if view == tableFooterView {
            tableFooterView = nil
        }
    }

    open override var intrinsicContentSize: CGSize {
        guard layoutNode != nil else {
            return super.intrinsicContentSize
        }
        return CGSize(
            width: contentSize.width + contentInset.left + contentInset.right,
            height: contentSize.height + contentInset.top + contentInset.bottom
        )
    }

    open override var contentSize: CGSize {
        didSet {
            if oldValue != contentSize, let layoutNode = layoutNode {
                let contentOffset = self.contentOffset.y
                layoutNode.update()
                if contentOffset >= 0 {
                    self.contentOffset.y = contentOffset
                }
            }
        }
    }

    open override func didUpdateLayout(for _: LayoutNode) {
        for cell in visibleCells {
            cell.layoutNode?.update()
        }
    }
}

extension UITableViewController {
    open override class func create(with node: LayoutNode) throws -> UITableViewController {
        let style = try node.value(forExpression: "style") as? UITableViewStyle ?? .plain
        let viewController = self.init(style: style)
        if !node.children.contains(where: { $0.viewClass is UITableView.Type }) {
            viewController.tableView.enableAutoSizing()
        } else if node.expressions.keys.contains(where: { $0.hasPrefix("tableView.") }) {
            // TODO: figure out how to propagate this config to the view once it has been created
        }
        objc_setAssociatedObject(viewController.tableView, &layoutNodeKey, Box(node), .OBJC_ASSOCIATION_RETAIN)
        return viewController
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return [
            "style": tableViewStyle,
        ]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (key, type) in UITableView.cachedExpressionTypes {
            types["tableView.\(key)"] = type
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case _ where name.hasPrefix("tableView."):
            try tableView.setValue(value, forExpression: String(name["tableView.".endIndex ..< name.endIndex]))
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        // TODO: what if more than one tableView is added?
        if node.viewClass is UITableView.Type {
            let wasLoaded = (viewIfLoaded != nil)
            tableView = node.view as? UITableView
            if wasLoaded {
                viewDidLoad()
            }
            return
        }
        tableView.didInsertChildNode(node, at: index)
    }

    open override func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        if node.viewClass is UITableView.Type {
            tableView = nil
            return
        }
        tableView.willRemoveChildNode(node, at: index)
    }
}

extension UITableView: LayoutDelegate {
    func layoutError(_ error: LayoutError) {
        DispatchQueue.main.async {
            var responder: UIResponder? = self.next
            while responder != nil {
                if let errorHandler = responder as? LayoutLoading {
                    errorHandler.layoutError(error)
                    break
                }
                responder = responder?.next ?? (responder as? UIViewController)?.parent
            }
            print("Layout error: \(error)")
        }
    }

    func value(forVariableOrConstant name: String) -> Any? {
        guard let layoutNode = layoutNode,
            let value = try? layoutNode.value(forVariableOrConstant: name) else {
            return nil
        }
        return value
    }
}

private var cellDataKey = 0
private var headerDataKey = 0
private var nodesKey = 0

extension UITableView {
    private enum LayoutData {
        case success(Layout, Any, [String: Any])
        case failure(Error)
    }

    private func registerLayoutData(
        _ layoutData: LayoutData,
        forReuseIdentifier identifier: String,
        key: UnsafeRawPointer
    ) {
        var layoutsData = objc_getAssociatedObject(self, key) as? NSMutableDictionary
        if layoutsData == nil {
            layoutsData = [:]
            objc_setAssociatedObject(self, key, layoutsData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        layoutsData![identifier] = layoutData
    }

    fileprivate func registerLayout(
        _ layout: Layout,
        state: Any = (),
        constants: [String: Any]...,
        forReuseIdentifier identifier: String,
        key: UnsafeRawPointer
    ) {
        registerLayoutData(
            .success(layout, state, merge(constants)),
            forReuseIdentifier: identifier,
            key: key
        )
    }

    // MARK: UITableViewHeaderFooterView recycling

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
                forReuseIdentifier: identifier,
                key: &headerDataKey
            )
        } catch {
            layoutError(LayoutError(error))
            registerLayoutData(.failure(error), forReuseIdentifier: identifier, key: &headerDataKey)
        }
    }

    public func dequeueReusableHeaderFooterNode(withIdentifier identifier: String) -> LayoutNode? {
        if let view = dequeueReusableHeaderFooterView(withIdentifier: identifier) {
            guard let node = view.layoutNode else {
                preconditionFailure("\(type(of: view)) is not a Layout-managed view")
            }
            if !view.isHidden {
                node.update()
                return node
            }
            // TODO: reusing a tableHeaderFooterView after reload causes it to be
            // permanently hidden, which breaks layout. figure out why that is
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
                nodes?.add(node)
                node.delegate = self
                try node.bind(to: node.view) // TODO: find a better solution for binding
                node._view?.setValue(identifier, forKey: "reuseIdentifier")
                return node
            case let .failure(error):
                throw error
            }
        } catch {
            layoutError(LayoutError(error))
            return nil
        }
    }

    // MARK: UITableViewCell recycling

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
                forReuseIdentifier: identifier,
                key: &cellDataKey
            )
        } catch {
            layoutError(LayoutError(error))
            registerLayoutData(.failure(error), forReuseIdentifier: identifier, key: &cellDataKey)
        }
    }

    public func dequeueReusableCellNode(withIdentifier identifier: String) -> LayoutNode? {
        if let cell = dequeueReusableCell(withIdentifier: identifier) {
            guard let node = cell.layoutNode else {
                preconditionFailure("\(type(of: cell)) is not a Layout-managed view")
            }
            return node
        }
        guard let layoutsData = objc_getAssociatedObject(self, &cellDataKey) as? NSMutableDictionary,
            let layoutData = layoutsData[identifier] as? LayoutData else {
            return nil
        }
        do {
            switch layoutData {
            case let .success(layout, state, constants):
                let node = try LayoutNode(
                    layout: layout,
                    state: state,
                    constants: constants
                )
                if node._view == nil, node.viewClass != UITableViewCell.self, node.expressions["style"] != nil {
                    throw Expression.Error.message("Setting style for UITableViewCell subclasses is not supported")
                }
                var nodes = objc_getAssociatedObject(self, &nodesKey) as? NSMutableArray
                if nodes == nil {
                    nodes = []
                    objc_setAssociatedObject(self, &nodesKey, nodes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
                nodes?.add(node)
                node.delegate = self
                try node.bind(to: node.view) // TODO: find a better solution for binding
                let cell = node.view
                cell.setValue(identifier, forKey: "reuseIdentifier")
                node._suppressUpdates = true
                cell.frame.size = CGSize(
                    width: bounds.width,
                    height: estimatedRowHeight > 0 ? estimatedRowHeight : rowHeight
                )
                node._suppressUpdates = false
                return node
            case let .failure(error):
                throw error
            }
        } catch {
            layoutError(LayoutError(error))
            return nil
        }
    }

    public func dequeueReusableCellNode(withIdentifier identifier: String, for _: IndexPath) -> LayoutNode {
        guard let node = dequeueReusableCellNode(withIdentifier: identifier) else {
            let layoutsData = objc_getAssociatedObject(self, &cellDataKey) as? NSMutableDictionary
            if layoutsData?[identifier] == nil {
                layoutError(.message("No cell layout has been registered for \(identifier)"))
            }
            return LayoutNode(view: UITableViewCell())
        }
        return node
    }
}

private let tableViewCellStyle = RuntimeType(UITableViewCellStyle.self, [
    "default": .default,
    "value1": .value1,
    "value2": .value2,
    "subtitle": .subtitle,
] as [String: UITableViewCellStyle])

extension UITableViewHeaderFooterView {
    weak var layoutNode: LayoutNode? {
        return (objc_getAssociatedObject(self, &layoutNodeKey) as? Box)?.node
    }

    open override class func create(with node: LayoutNode) throws -> UITableViewHeaderFooterView {
        let reuseIdentifier = try node.value(forExpression: "reuseIdentifier") as? String
        let view = self.init() // Workaround for `self.init(reuseIdentifier:)` causing build failure
        view.setValue(reuseIdentifier, forKey: "reuseIdentifier")
        if node.expressions.keys.contains(where: { $0.hasPrefix("backgroundView.") }),
            !node.expressions.keys.contains("backgroundView") {
            // Add a background view if required
            view.backgroundView = UIView(frame: view.bounds)
        }
        objc_setAssociatedObject(view, &layoutNodeKey, Box(node), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return view
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return [
            "reuseIdentifier": RuntimeType(String.self),
        ]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["backgroundColor"] = .unavailable("Setting backgroundColor on UITableViewHeaderFooterView is not supported. Use contentView.backgroundColor instead.")
        types["editingAccessoryType"] = types["accessoryType"]
        for (key, type) in UIView.cachedExpressionTypes {
            types["contentView.\(key)"] = type
            types["backgroundView.\(key)"] = type
        }
        for (key, type) in UILabel.cachedExpressionTypes {
            types["textLabel.\(key)"] = type
            types["detailTextLabel.\(key)"] = type
        }

        #if arch(i386) || arch(x86_64)
            // Private and read-only properties
            for name in [
                "backgroundImage",
                "floating",
                "maxTitleWidth",
                "text",
                "textAlignment",
            ] + [
                "reuseIdentifier",
                "sectionHeader",
                "table",
                "tableView",
                "tableViewStyle",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func didInsertChildNode(_ node: LayoutNode, at _: Int) {
        if let viewController = self.viewController {
            for controller in node.viewControllers {
                viewController.addChildViewController(controller)
            }
        }
        // Insert child views into `contentView` instead of directly
        contentView.addSubview(node.view) // Ignore index
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
    fileprivate weak var layoutNode: LayoutNode? {
        return (objc_getAssociatedObject(self, &layoutNodeKey) as? Box)?.node
    }

    open override class func create(with node: LayoutNode) throws -> UITableViewCell {
        let style = try node.value(forExpression: "style") as? UITableViewCellStyle ?? .default
        let reuseIdentifier = try node.value(forExpression: "reuseIdentifier") as? String
        let cell: UITableViewCell
        if self == UITableViewCell.self {
            cell = UITableViewCell(style: style, reuseIdentifier: reuseIdentifier)
        } else {
            cell = self.init() // Workaround for `self.init(style:reuseIdentifier:)` causing build failure
            cell.setValue(reuseIdentifier, forKey: "reuseIdentifier")
        }
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

    open override class var parameterTypes: [String: RuntimeType] {
        return [
            "style": tableViewCellStyle,
            "reuseIdentifier": RuntimeType(String.self),
        ]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["selectionStyle"] = RuntimeType(UITableViewCellSelectionStyle.self, [
            "none": .none,
            "blue": .blue,
            "gray": .gray,
            "default": .default,
        ] as [String: UITableViewCellSelectionStyle])
        types["focusStyle"] = RuntimeType(UITableViewCellFocusStyle.self, [
            "default": .default,
            "custom": .custom,
        ] as [String: UITableViewCellFocusStyle])
        types["accessoryType"] = RuntimeType(UITableViewCellAccessoryType.self, [
            "none": .none,
            "disclosureIndicator": .disclosureIndicator,
            "detailDisclosureButton": .detailDisclosureButton,
            "checkmark": .checkmark,
            "detailButton": .detailButton,
        ] as [String: UITableViewCellAccessoryType])
        types["editingAccessoryType"] = types["accessoryType"]
        for (key, type) in UIView.cachedExpressionTypes {
            types["contentView.\(key)"] = type
            types["backgroundView.\(key)"] = type
            types["selectedBackgroundView.\(key)"] = type
        }
        for (key, type) in UIImageView.cachedExpressionTypes {
            types["imageView.\(key)"] = type
        }
        for (key, type) in UILabel.cachedExpressionTypes {
            types["textLabel.\(key)"] = type
            types["detailTextLabel.\(key)"] = type
        }

        #if arch(i386) || arch(x86_64)
            // Private and read-only properties
            for name in [
                "accessoryAction",
                "bottomShadowColor",
                "clipsContents",
                "drawingEnabled",
                "hidesAccessoryWhenEditing",
                "lineBreakMode",
                "returnAction",
                "sectionBorderColor",
                "sectionLocation",
                "selectedTextColor",
                "selectionFadeDuration",
                "selectionTintColor",
                "separatorColor",
                "separatorStyle",
                "tableBackgroundColor",
                "tableSpecificElementsHidden",
                "tableViewStyle",
                "textAlignment",
                "textColor",
                "textFieldOffset",
                "topShadowColor",
                "wasSwiped",
            ] + [
                "reuseIdentifier",
                "showingDeleteConfirmation",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "isEditing":
            setEditing(value as! Bool, animated: true)
        case "isSelected":
            setSelected(value as! Bool, animated: true)
        case "isHighlighted":
            setHighlighted(value as! Bool, animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at _: Int) {
        if let viewController = self.viewController {
            for controller in node.viewControllers {
                viewController.addChildViewController(controller)
            }
        }
        // Insert child views into `contentView` instead of directly
        contentView.addSubview(node.view) // Ignore index
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        if let layoutNode = layoutNode {
            let height = (try? layoutNode.doubleValue(forSymbol: "height")) ?? 0
            return CGSize(width: size.width, height: CGFloat(height))
        }
        return super.sizeThatFits(size)
    }
}
