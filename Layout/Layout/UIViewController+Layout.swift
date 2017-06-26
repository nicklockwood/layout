//
//  UIViewController+Layout.swift
//  Layout
//
//  Created by Nick Lockwood on 05/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

private var _cachedExpressionTypes = [Int: [String: RuntimeType]]()

extension UIViewController {

    /// Expression names and types
    @objc open class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        types["tabBarItem.title"] = RuntimeType(String.self)
        types["tabBarItem.image"] = RuntimeType(UIImage.self)
        types["tabBarItem.selectedImage"] = RuntimeType(UIImage.self)
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

    private func updateTabBarItem(title: String? = nil, image: UIImage? = nil, selectedImage: UIImage? = nil) {
        let title = title ?? tabBarItem?.title
        let image = image ?? tabBarItem?.image
        let selectedImage = selectedImage ?? tabBarItem?.selectedImage
        if tabBarItem?.title != title ||
            tabBarItem?.image != image ||
            tabBarItem?.selectedImage != selectedImage {
            tabBarItem = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
        }
    }

    /// Called to construct the view
    @objc open class func create(with node: LayoutNode) throws -> UIViewController {
        return self.init()
    }

    // Set expression value
    @objc open func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "tabBarItem.title":
            updateTabBarItem(title: value as? String)
        case "tabBarItem.image":
            updateTabBarItem(image: value as? UIImage)
        case "tabBarItem.selectedImage":
            updateTabBarItem(selectedImage: value as? UIImage)
        case "tabBarItem.systemItem":
            tabBarItem = UITabBarItem(tabBarSystemItem: value as! UITabBarSystemItem, tag: 0)
        default:
            var value = value
            if let type = type(of: self).cachedExpressionTypes[name]?.type, case let .enum(_, _, adaptor) = type {
                value = adaptor(value) // TODO: something nicer than this
            }
            try _setValue(value, forKeyPath: name)
        }
    }

    /// Get symbol value
    @objc open func value(forSymbol name: String) -> Any? {
        return _value(forKeyPath: name)
    }

    /// Called immediately after a child node is added
    @objc open func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        for controller in node.viewControllers {
            addChildViewController(controller)
        }
        view.addSubview(node.view)
    }

    /// Called immediately before a child node is removed
    @objc open func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        for controller in node.viewControllers {
            controller.removeFromParentViewController()
        }
        node.view.removeFromSuperview()
    }

    /// Called immediately after layout has been performed
    @objc open func didUpdateLayout(for node: LayoutNode) {}
}

extension UITabBarController {
    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = node.viewController {
            var viewControllers = self.viewControllers ?? []
            viewControllers.insert(viewController, at: index)
            self.setViewControllers(viewControllers, animated: false)
        } else {
            super.didInsertChildNode(node, at: index)
        }
    }

    open override func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = node.viewController,
            var viewControllers = self.viewControllers,
            let index = viewControllers.index(of: viewController) {
            viewControllers.remove(at: index)
            self.setViewControllers(viewControllers, animated: false)
        } else {
            super.willRemoveChildNode(node, at: index)
        }
    }
}

extension UINavigationController {
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

private let tableViewStyle = RuntimeType(UITableViewStyle.self, [
    "plain": .plain,
    "grouped": .grouped,
])

extension UITableViewController {
    open override class func create(with node: LayoutNode) throws -> UIViewController {
        var style = UITableViewStyle.plain
        if let expression = node.expressions["style"] {
            let styleExpression = LayoutExpression(expression: expression, type: tableViewStyle, for: node)
            style = try styleExpression.evaluate() as! UITableViewStyle
        }
        return UITableViewController(style: style)
    }
}
