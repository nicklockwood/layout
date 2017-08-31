//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

private var _cachedExpressionTypes = [Int: [String: RuntimeType]]()

private let barButtonSystemItemType = RuntimeType(UIBarButtonSystemItem.self, [
    "done": .done,
    "cancel": .cancel,
    "edit": .edit,
    "save": .add,
    "flexibleSpace": .flexibleSpace,
    "fixedSpace": .fixedSpace,
    "compose": .compose,
    "reply": .reply,
    "action": .action,
    "organize": .organize,
    "bookmarks": .bookmarks,
    "search": .search,
    "refresh": .refresh,
    "stop": .stop,
    "camera": .camera,
    "trash": .trash,
    "play": .play,
    "pause": .pause,
    "rewind": .rewind,
    "fastForward": .fastForward,
    "undo": .undo,
    "redo": .redo,
    "pageCurl": .pageCurl,
])

extension UIBarButtonItem {
    func bindAction(for target: AnyObject) throws {
        guard self.target !== target, let action = action else {
            return
        }
        if !target.responds(to: action) {
            throw LayoutError.message("\(target.classForCoder ?? type(of: target)) does not respond to \(action)")
        }
        self.target = target
    }

    func unbindAction(for target: AnyObject) {
        if self.target === target {
            self.target = nil
        }
    }
}

extension UIViewController {

    /// Expression names and types
    @objc open class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        for (name, type) in UITabBarItem.allPropertyTypes() {
            types["tabBarItem.\(name)"] = type
        }
        types["tabBarItem.title"] = RuntimeType(String.self)
        types["tabBarItem.image"] = RuntimeType(UIImage.self)
        types["tabBarItem.systemItem"] = RuntimeType(UITabBarSystemItem.self, [
            "more": .more,
            "favorites": .favorites,
            "featured": .featured,
            "topRated": .topRated,
            "recents": .recents,
            "contacts": .contacts,
            "history": .history,
            "bookmarks": .bookmarks,
            "search": .search,
            "downloads": .downloads,
            "mostRecent": .mostRecent,
            "mostViewed": .mostViewed,
        ])
        // TODO: tabBarItem.badgeTextAttributes
        for (name, type) in UINavigationItem.allPropertyTypes() {
            types["navigationItem.\(name)"] = type
        }
        for (name, type) in UIBarButtonItem.allPropertyTypes() {
            types["navigationItem.leftBarButtonItem.\(name)"] = type
            types["navigationItem.rightBarButtonItem.\(name)"] = type
        }
        types["navigationItem.leftBarButtonItem.systemItem"] = barButtonSystemItemType
        types["navigationItem.rightBarButtonItem.systemItem"] = barButtonSystemItemType
        // TODO: barButtonItem.backgroundImage, etc
        return types
    }

    class var cachedExpressionTypes: [String: RuntimeType] {
        if let types = _cachedExpressionTypes[self.hash()] {
            return types
        }
        let types = expressionTypes
        _cachedExpressionTypes[self.hash()] = types
        return types
    }

    private func copyTabBarItemProps(from oldItem: UITabBarItem, to newItem: UITabBarItem) {
        newItem.badgeValue = oldItem.badgeValue
        if #available(iOS 10.0, *) {
            newItem.badgeColor = oldItem.badgeColor
        }
        newItem.titlePositionAdjustment = oldItem.titlePositionAdjustment
        // TODO: badgeTextAttributes
    }

    private func updateTabBarItem(title: String? = nil, image: UIImage? = nil) {
        guard let oldItem = tabBarItem else {
            tabBarItem = UITabBarItem(title: title, image: image, tag: 0)
            return
        }
        let title = title ?? tabBarItem.title
        let image = image ?? tabBarItem.image
        if tabBarItem.title != title || tabBarItem.image != image {
            tabBarItem = UITabBarItem(title: title, image: image, selectedImage: oldItem.selectedImage)
            copyTabBarItemProps(from: oldItem, to: tabBarItem)
        }
    }

    private func updateTabBarItem(systemItem: UITabBarSystemItem) {
        guard let oldTabBarItem = tabBarItem else {
            tabBarItem = UITabBarItem(tabBarSystemItem: systemItem, tag: 0)
            return
        }
        tabBarItem = UITabBarItem(tabBarSystemItem: systemItem, tag: 0)
        tabBarItem.badgeValue = oldTabBarItem.badgeValue
        if #available(iOS 10.0, *) {
            tabBarItem.badgeColor = oldTabBarItem.badgeColor
        }
        tabBarItem.titlePositionAdjustment = oldTabBarItem.titlePositionAdjustment
    }

    private func copyBarItemProps(from oldItem: UIBarButtonItem, to newItem: UIBarButtonItem) {
        newItem.width = oldItem.width
        newItem.possibleTitles = oldItem.possibleTitles
        newItem.customView = oldItem.customView
        newItem.tintColor = oldItem.tintColor
        // TODO: backgroundImage, etc
    }

    private func updatedBarItem(_ item: UIBarButtonItem?, title: String) -> UIBarButtonItem {
        guard var item = item else {
            return UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
        }
        if item.title != title {
            let oldItem = item
            item = UIBarButtonItem(title: title, style: oldItem.style, target: oldItem.target, action: oldItem.action)
            copyBarItemProps(from: oldItem, to: item)
        }
        return item
    }

    private func updatedBarItem(_ item: UIBarButtonItem?, image: UIImage) -> UIBarButtonItem {
        guard var item = item else {
            return UIBarButtonItem(image: image, style: .plain, target: nil, action: nil)
        }
        if item.image != image {
            let oldItem = item
            item = UIBarButtonItem(image: image, style: oldItem.style, target: oldItem.target, action: oldItem.action)
            copyBarItemProps(from: oldItem, to: item)
        }
        return item
    }

    private func updatedBarItem(_ item: UIBarButtonItem?, systemItem: UIBarButtonSystemItem) -> UIBarButtonItem {
        guard var item = item else {
            return UIBarButtonItem(barButtonSystemItem: systemItem, target: nil, action: nil)
        }
        let oldItem = item
        item = UIBarButtonItem(barButtonSystemItem: systemItem, target: oldItem.target, action: oldItem.action)
        copyBarItemProps(from: oldItem, to: item)
        return item
    }

    /// Constructor argument names and types
    @objc open class var parameterTypes: [String: RuntimeType] {
        return [:]
    }

    /// Called to construct the view
    @objc open class func create(with _: LayoutNode) throws -> UIViewController {
        return self.init()
    }

    // Set expression value
    @objc open func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "tabBarItem.title":
            updateTabBarItem(title: value as? String)
        case "tabBarItem.image":
            updateTabBarItem(image: value as? UIImage)
        case "tabBarItem.systemItem":
            updateTabBarItem(systemItem: value as! UITabBarSystemItem)
        case "navigationItem.leftBarButtonItem.title":
            navigationItem.leftBarButtonItem = updatedBarItem(navigationItem.leftBarButtonItem, title: value as! String)
        case "navigationItem.leftBarButtonItem.image":
            navigationItem.leftBarButtonItem = updatedBarItem(navigationItem.leftBarButtonItem, image: value as! UIImage)
        case "navigationItem.leftBarButtonItem.systemItem":
            navigationItem.leftBarButtonItem = updatedBarItem(navigationItem.leftBarButtonItem, systemItem: value as! UIBarButtonSystemItem)
        case "navigationItem.rightBarButtonItem.title":
            navigationItem.rightBarButtonItem = updatedBarItem(navigationItem.rightBarButtonItem, title: value as! String)
        case "navigationItem.rightBarButtonItem.image":
            navigationItem.rightBarButtonItem = updatedBarItem(navigationItem.rightBarButtonItem, image: value as! UIImage)
        case "navigationItem.rightBarButtonItem.systemItem":
            navigationItem.rightBarButtonItem = updatedBarItem(navigationItem.rightBarButtonItem, systemItem: value as! UIBarButtonSystemItem)
        default:
            if name.hasPrefix("navigationItem.leftBarButtonItem."), navigationItem.leftBarButtonItem == nil {
                navigationItem.leftBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            } else if name.hasPrefix("navigationItem.rightBarButtonItem."), navigationItem.rightBarButtonItem == nil {
                navigationItem.rightBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            }
            try _setValue(value, ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name)
        }
    }

    /// Get symbol value
    @objc open func value(forSymbol name: String) throws -> Any {
        return try _value(ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name) as Any
    }

    /// Called immediately after a child node is added
    @objc open func didInsertChildNode(_ node: LayoutNode, at _: Int) {
        for controller in node.viewControllers {
            addChildViewController(controller)
        }
        node.view.frame = view.bounds
        view.addSubview(node.view)
    }

    /// Called immediately before a child node is removed
    @objc open func willRemoveChildNode(_ node: LayoutNode, at _: Int) {
        for controller in node.viewControllers {
            controller.removeFromParentViewController()
        }
        node.view.removeFromSuperview()
    }

    /// Called immediately after layout has been performed
    @objc open func didUpdateLayout(for _: LayoutNode) {}
}

extension UITabBarController {
    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = node.viewController {
            var viewControllers = self.viewControllers ?? []
            viewControllers.insert(viewController, at: index)
            setViewControllers(viewControllers, animated: false)
        } else {
            super.didInsertChildNode(node, at: index)
        }
    }

    open override func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = node.viewController,
            var viewControllers = self.viewControllers,
            let index = viewControllers.index(of: viewController) {
            viewControllers.remove(at: index)
            setViewControllers(viewControllers, animated: false)
        } else {
            super.willRemoveChildNode(node, at: index)
        }
    }
}

extension UINavigationController {
    open override class func create(with node: LayoutNode) throws -> UINavigationController {
        let navigationBarClass = try node.value(forExpression: "navigationBarClass") as? UINavigationBar.Type
        let toolbarClass = try node.value(forExpression: "toolbarClass") as? UIToolbar.Type
        return self.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return [
            "navigationBarClass": RuntimeType(class: UINavigationBar.self),
            "toolbarClass": RuntimeType(class: UIToolbar.self),
        ]
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = node.viewController {
            var viewControllers = self.viewControllers
            viewControllers.insert(viewController, at: index)
            self.viewControllers = viewControllers
        } else {
            super.didInsertChildNode(node, at: index)
        }
    }

    open override func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        var viewControllers = self.viewControllers
        if let viewController = node.viewController,
            let index = viewControllers.index(of: viewController) {
            viewControllers.remove(at: index)
            self.viewControllers = viewControllers
        } else {
            super.willRemoveChildNode(node, at: index)
        }
    }
}
