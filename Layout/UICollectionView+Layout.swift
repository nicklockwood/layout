//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

private let placeholderID = NSUUID().uuidString

private let collectionViewScrollDirection = RuntimeType(UICollectionViewScrollDirection.self, [
    "horizontal": .horizontal,
    "vertical": .vertical,
])

extension UICollectionView {
    open override class func create(with node: LayoutNode) throws -> UICollectionView {
        let layout: UICollectionViewLayout
        if let expression = node.expressions["collectionViewLayout"] {
            let layoutExpression = LayoutExpression(
                expression: expression,
                type: RuntimeType(UICollectionViewLayout.self),
                for: node
            )
            layout = try layoutExpression.evaluate() as! UICollectionViewLayout
        } else {
            layout = defaultLayout(for: node)
        }
        let collectionView = self.init(frame: .zero, collectionViewLayout: layout)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: placeholderID)
        return collectionView
    }

    fileprivate static func defaultLayout(for node: LayoutNode) -> UICollectionViewFlowLayout {
        let flowLayout = UICollectionViewFlowLayout()
        if node.expressions["collectionViewLayout.itemSize"] ??
            node.expressions["collectionViewLayout.itemSize.width"] ??
            node.expressions["collectionViewLayout.itemSize.height"] == nil {
            flowLayout.estimatedItemSize = flowLayout.itemSize
        }
        if #available(iOS 10.0, *) {
            flowLayout.itemSize = UICollectionViewFlowLayoutAutomaticSize
        } else {
            flowLayout.itemSize = CGSize(width: UIViewNoIntrinsicMetric, height: UIViewNoIntrinsicMetric)
        }
        return flowLayout
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (key, type) in UICollectionViewFlowLayout.allPropertyTypes() {
            types["collectionViewLayout.\(key)"] = type
        }
        types["collectionViewLayout.scrollDirection"] = collectionViewScrollDirection
        return types
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        let hadView = (node._view != nil)
        switch node.viewClass {
        case is UICollectionViewCell.Type:
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
                layoutError(.message("UICollectionViewCell template missing reuseIdentifier"))
            }
        default:
            if backgroundView == nil {
                backgroundView = node.view
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
        if node._view == backgroundView {
            backgroundView = nil
        }
        // Check we didn't accidentally instantiate the view
        // TODO: it would be better to do this in a unit test
        assert(hadView || node._view == nil)
    }

    public func layoutError(_ error: LayoutError) {
        var responder: UIResponder? = self
        while responder != nil {
            if let errorHandler = responder as? LayoutLoading {
                errorHandler.layoutError(error)
                break
            }
            responder = responder?.next
        }
        print("Layout error: \(error)")
    }
}

extension UICollectionViewController {
    open override class func create(with node: LayoutNode) throws -> UICollectionViewController {
        let layout: UICollectionViewLayout
        if let expression = node.expressions["collectionViewLayout"] {
            let layoutExpression = LayoutExpression(
                expression: expression,
                type: RuntimeType(UICollectionViewLayout.self),
                for: node
            )
            layout = try layoutExpression.evaluate() as! UICollectionViewLayout
        } else {
            layout = UICollectionView.defaultLayout(for: node)
        }
        let viewController = self.init(collectionViewLayout: layout)
        if !node.children.contains(where: { $0.viewClass is UICollectionView.Type }) {
            viewController.collectionView?.register(UICollectionViewCell.self, forCellWithReuseIdentifier: placeholderID)
        } else if node.expressions.keys.contains(where: { $0.hasPrefix("collectionView.") }) {
            // TODO: figure out how to propagate this config to the view once it has been created
        }
        return viewController
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (key, type) in UICollectionViewFlowLayout.allPropertyTypes() {
            types["collectionViewLayout.\(key)"] = type
        }
        types["collectionViewLayout.scrollDirection"] = collectionViewScrollDirection
        for (key, type) in UICollectionView.cachedExpressionTypes {
            types["collectionView.\(key)"] = type
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case _ where name.hasPrefix("collectionView."):
            try collectionView?.setValue(value, forExpression: name.substring(from: "collectionView.".endIndex))
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        // TODO: what if more than one collectionView is added?
        if node.viewClass is UICollectionView.Type {
            let wasLoaded = (viewIfLoaded != nil)
            collectionView = node.view as? UICollectionView
            if wasLoaded {
                viewDidLoad()
            }
            return
        }
        collectionView?.didInsertChildNode(node, at: index)
    }

    open override func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        if node.viewClass is UICollectionView.Type {
            collectionView = nil
            return
        }
        collectionView?.willRemoveChildNode(node, at: index)
    }
}


private var cellDataKey = 0
private var nodesKey = 0

extension UICollectionView: LayoutDelegate {

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

    private func registerLayoutData(
        _ layoutData: LayoutData,
        forCellReuseIdentifier identifier: String
    ) {
        var layoutsData = objc_getAssociatedObject(self, &cellDataKey) as? NSMutableDictionary
        if layoutsData == nil {
            layoutsData = [:]
            objc_setAssociatedObject(self, &cellDataKey, layoutsData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        layoutsData![identifier] = layoutData
    }

    fileprivate func registerLayout(
        _ layout: Layout,
        state: Any = (),
        constants: [String: Any]...,
        forCellReuseIdentifier identifier: String
    ) {
        do {
            let viewClass: AnyClass = try layout.getClass()
            guard let cellClass = viewClass as? UICollectionViewCell.Type else {
                throw LayoutError.message("\(viewClass)) is not a subclass of UICollectionViewCell")
            }
            register(cellClass as AnyClass, forCellWithReuseIdentifier: identifier)
            registerLayoutData(.success(layout, state, merge(constants)), forCellReuseIdentifier: identifier)
        } catch {
            layoutError(LayoutError(error))
            registerLayoutData(.failure(error), forCellReuseIdentifier: identifier)
        }
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

    public func dequeueReusableCellNode(withIdentifier identifier: String, for indexPath: IndexPath) -> LayoutNode {
        do {
            guard let layoutsData = objc_getAssociatedObject(self, &cellDataKey) as? NSMutableDictionary,
                let layoutData = layoutsData[identifier] as? LayoutData else {
                throw LayoutError.message("No cell layout has been registered for \(identifier)")
            }
            let cell = dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
            if let node = cell.layoutNode {
                return node
            }
            switch layoutData {
            case let .success(layout, state, constants):
                let node = try LayoutNode(
                    layout: layout,
                    state: state,
                    constants: constants
                )
                var nodes = objc_getAssociatedObject(self, &nodesKey) as? NSMutableArray
                if nodes == nil {
                    nodes = []
                    objc_setAssociatedObject(self, &nodesKey, nodes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
                nodes?.add(node)
                node.delegate = self
                assert(node._view == nil)
                node._view = cell
                cell.layoutNode = node
                return node
            case let .failure(error):
                throw error
            }
        } catch {
            layoutError(LayoutError(error))
            return LayoutNode(view: dequeueReusableCell(withReuseIdentifier: placeholderID, for: indexPath))
        }
    }
}

private var layoutNodeKey = 0

private class Box {
    weak var node: LayoutNode?
    init(_ node: LayoutNode) {
        self.node = node
    }
}

extension UICollectionViewCell {
    weak var layoutNode: LayoutNode? {
        get {
            return (objc_getAssociatedObject(self, &layoutNodeKey) as? Box)?.node
        }
        set {
            objc_setAssociatedObject(self, &layoutNodeKey, newValue.map(Box.init), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    open override class func create(with _: LayoutNode) throws -> UICollectionViewCell {
        throw LayoutError.message("UICollectionViewCells must be created by UICollectionView")
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["reuseIdentifier"] = RuntimeType(String.self)
        for (key, type) in UIView.expressionTypes {
            types["contentView.\(key)"] = type
            types["backgroundView.\(key)"] = type
            types["selectedBackgroundView.\(key)"] = type
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "reuseIdentifier":
            break // Ignore this, it's only used for template cells
        default:
            if name.hasPrefix("backgroundView."), backgroundView == nil {
                // Add a backgroundView view if required
                backgroundView = UIView(frame: bounds)
            }
            if name.hasPrefix("selectedBackgroundView."), selectedBackgroundView == nil {
                // Add a selectedBackgroundView view if required
                selectedBackgroundView = UIView(frame: bounds)
            }
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
