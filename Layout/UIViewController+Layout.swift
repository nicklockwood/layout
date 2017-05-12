//
//  UIViewController+Layout.swift
//  Layout
//
//  Created by Nick Lockwood on 05/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

extension UIViewController {

    /// Expression names and types
    open class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        types["tabBarItem.title"] = RuntimeType(String.self)
        types["tabBarItem.image"] = RuntimeType(UIImage.self)
        types["tabBarItem.selectedImage"] = RuntimeType(UIImage.self)
        types["tabBarItem.systemItem"] = RuntimeType([
            "more": UITabBarSystemItem.more.rawValue,
            "favorites": UITabBarSystemItem.favorites.rawValue,
            "featured": UITabBarSystemItem.featured.rawValue,
            "topRated": UITabBarSystemItem.topRated.rawValue,
            "recents": UITabBarSystemItem.recents.rawValue,
            "contacts": UITabBarSystemItem.contacts.rawValue,
            "history": UITabBarSystemItem.history.rawValue,
            "bookmarks": UITabBarSystemItem.bookmarks.rawValue,
            "search": UITabBarSystemItem.search.rawValue,
            "downloads": UITabBarSystemItem.downloads.rawValue,
            "mostRecent": UITabBarSystemItem.mostRecent.rawValue,
            "mostViewed": UITabBarSystemItem.mostViewed.rawValue,
        ])
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

    // Set expression value
    open func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "tabBarItem.title":
            updateTabBarItem(title: value as? String)
        case "tabBarItem.image":
            updateTabBarItem(image: value as? UIImage)
        case "tabBarItem.selectedImage":
            updateTabBarItem(selectedImage: value as? UIImage)
        case "tabBarItem.systemItem":
            tabBarItem = UITabBarItem(tabBarSystemItem: UITabBarSystemItem(rawValue: value as! Int)!, tag: 0)
        default:
            try _setValue(value, forKeyPath: name)
        }
    }

    /// Get symbol value
    open func value(forSymbol name: String) -> Any? {
        return _value(forKeyPath: name)
    }

    /// Called immediately after a child node is added
    open func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        for controller in node.viewControllers {
            addChildViewController(controller)
        }
        view.addSubview(node.view)
    }

    /// Called immediately before a child node is removed
    open func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        for controller in node.viewControllers {
            controller.removeFromParentViewController()
        }
        node.view.removeFromSuperview()
    }

    /// Called immediately after layout has been performed
    open func didUpdateLayout(for node: LayoutNode) {}
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
