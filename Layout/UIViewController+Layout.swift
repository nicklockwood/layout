//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

private var _cachedExpressionTypes = [Int: [String: RuntimeType]]()

private let barButtonSystemItemType = RuntimeType([
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
] as [String: UIBarButtonSystemItem])

private let barButtonItemStyleType = RuntimeType([
    "plain": .plain,
    "done": .done,
] as [String: UIBarButtonItemStyle])

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
        types["tabBarItem.systemItem"] = RuntimeType([
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
        ] as [String: UITabBarSystemItem])
        types["edgesForExtendedLayout"] = RuntimeType([
            "top": .top,
            "left": .left,
            "bottom": .bottom,
            "right": .right,
            "all": .all,
        ] as [String: UIRectEdge])
        types["modalPresentationStyle"] = RuntimeType([
            "fullScreen": .fullScreen,
            "pageSheet": .pageSheet,
            "formSheet": .formSheet,
            "currentContext": .currentContext,
            "custom": .custom,
            "overFullScreen": .overFullScreen,
            "overCurrentContext": .overCurrentContext,
            "popover": .popover,
            "none": .none,
        ] as [String: UIModalPresentationStyle])
        types["modalTransitionStyle"] = RuntimeType([
            "coverVertical": .coverVertical,
            "flipHorizontal": .flipHorizontal,
            "crossDissolve": .crossDissolve,
            "partialCurl": .partialCurl,
        ] as [String: UIModalTransitionStyle])
        // TODO: tabBarItem.badgeTextAttributes
        for (name, type) in UINavigationItem.allPropertyTypes() {
            types["navigationItem.\(name)"] = type
        }
        #if swift(>=3.2)
            types["navigationItem.largeTitleDisplayMode"] = RuntimeType([
                "automatic": .automatic,
                "always": .always,
                "never": .never,
            ] as [String: UINavigationItem.LargeTitleDisplayMode])
        #else
            types["navigationItem.largeTitleDisplayMode"] = RuntimeType([
                "automatic": 0,
                "always": 1,
                "never": 2,
            ] as [String: Int])
        #endif
        for (name, type) in UIBarButtonItem.allPropertyTypes() {
            types["navigationItem.leftBarButtonItem.\(name)"] = type
            types["navigationItem.rightBarButtonItem.\(name)"] = type
        }
        types["navigationItem.leftBarButtonItem.style"] = barButtonItemStyleType
        types["navigationItem.leftBarButtonItem.systemItem"] = barButtonSystemItemType
        types["navigationItem.rightBarButtonItem.style"] = barButtonItemStyleType
        types["navigationItem.rightBarButtonItem.systemItem"] = barButtonSystemItemType
        // TODO: barButtonItem.backgroundImage, etc

        #if arch(i386) || arch(x86_64)
            // Private and read-only properties
            for name in [
                "SKUIStackedBarSplit",
                "aggregateStatisticsDisplayCountKey",
                "appearanceTransitionsAreDisabled",
                "autoresizesArchivedViewToFullSize",
                "childModalViewController",
                "containmentSupport",
                "contentSizeForViewInPopover",
                "customNavigationInteractiveTransitionDuration",
                "customNavigationInteractiveTransitionPercentComplete",
                "customTransitioningView",
                "disableRootPromotion",
                "dropShadowView",
                "formSheetSize",
                "ignoresParentMargins",
                "isFinishingModalTransition",
                "isInAnimatedVCTransition",
                "isInWillRotateCallback",
                "isPerformingModalTransition",
                "modalTransitionView",
                "mutableChildViewControllers",
                "navigationInsetAdjustment",
                "needsDidMoveCleanup",
                "overrideTraitCollection",
                "parentModalViewController",
                "preferredFocusedItem",
                "sKUIStackedBarSplit",
                "searchBarHidNavBar",
                "shouldForceNonAnimatedTransition",
                "showsBackgroundShadow",
                "storePageProtocol",
                "useLegacyContainment",
                "wantsFullScreenLayout",
            ] + [
                "disablesAutomaticKeyboardDismissal",
                "interfaceOrientation",
                "nibName",
                "nibBundle",
                "preferredFocusedView",
                "searchDisplayController",
                "view", // Not actually read-only, but Layout doesn't allow this to be set
            ] {
                types[name] = nil
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif

        // Workaround for Swift availability selector limitations
        if #available(iOS 10.0, *), self is UICloudSharingController.Type {
            types["availablePermissions"] = RuntimeType([
                "allowPublic": .allowPublic,
                "allowPrivate": .allowPrivate,
                "allowReadOnly": .allowReadOnly,
                "allowReadWrite": .allowReadWrite,
            ] as [String: UICloudSharingPermissionOptions])
        }

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
            // TODO: warn if badgeColor unsupported
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
            // TODO: warn if badgeColor unsupported
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

    /// Default expressions to use when not specified
    @objc open class var defaultExpressions: [String: String] {
        return [:]
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
        case "navigationItem.largeTitleDisplayMode":
            #if swift(>=3.2)
                if #available(iOS 11.0, *) {
                    navigationItem.largeTitleDisplayMode = value as! UINavigationItem.LargeTitleDisplayMode
                }
            #endif
        default:
            if name.hasPrefix("navigationItem.leftBarButtonItem."), navigationItem.leftBarButtonItem == nil {
                navigationItem.leftBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            } else if name.hasPrefix("navigationItem.rightBarButtonItem."), navigationItem.rightBarButtonItem == nil {
                navigationItem.rightBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            }
            try _setValue(value, ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name)
        }
    }

    // Set expression value with animation (if applicable)
    @objc open func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        let type = Swift.type(of: self).cachedExpressionTypes[name]
        if try !_setValue(value, ofType: type, forKey: name, animated: true) {
            try setValue(value, forExpression: name)
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

extension UITabBar {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["selectedImageTintColor"] = .unavailable() // Deprecated
        types["itemPositioning"] = RuntimeType([
            "automatic": .automatic,
            "fill": .fill,
            "centered": .centered,
        ] as [String: UITabBarItemPositioning])
        types["barStyle"] = barStyleType
        types["itemSpacing"] = RuntimeType(CGFloat.self)
        types["itemWidth"] = RuntimeType(CGFloat.self)

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "backgroundEffects",
                "barPosition",
                "isLocked",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "delegate":
            if viewController is UITabBarController {
                if value as? UIViewController == viewController {
                    break
                }
                throw LayoutError("Cannot change the delegate of a UITabBar managed by a UITabBarController")
            }
            fallthrough
        default:
            try _setValue(value, ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name)
        }
    }
}

extension UITabBarController {
    open override class func create(with node: LayoutNode) throws -> UITabBarController {
        let tabBarController = self.init()
        let tabBarType = type(of: tabBarController.tabBar)
        if let child = node.children.first(where: { $0._class is UITabBar.Type && $0._class != tabBarType }) {
            throw LayoutError("\(child._class) is not compatible with \(tabBarType)")
        }
        return tabBarController
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["selectedIndex"] = RuntimeType(Int.self)

        #if arch(i386) || arch(x86_64)
            // Private and read-only properties
            for name in [
                "moreChildViewControllers",
                "showsEditButtonOnLeft",
            ] + [
                "tabBar",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = node.viewController {
            var viewControllers = self.viewControllers ?? []
            viewControllers.append(viewController) // Ignore index
            setViewControllers(viewControllers, animated: false)
        } else if node.viewClass is UITabBar.Type {
            assert(node._view == nil)
            node._view = tabBar
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
        } else if !(node.viewClass is UITabBar.Type) {
            super.willRemoveChildNode(node, at: index)
        }
    }
}

extension UINavigationBar: TitleTextAttributes {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["backgroundImage"] = RuntimeType(UIImage.self)
        types["titleVerticalPositionAdjustment"] = RuntimeType(CGFloat.self)
        types["barStyle"] = barStyleType
        types["barPosition"] = barPositionType
        types["prefersLargeTitles"] = RuntimeType(Bool.self)

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "backgroundEffects",
                "forceFullHeightInLandscape",
                "isLocked",
                "requestedContentSize",
                "rightMargin",
                "titleAutoresizesToFit",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    var titleColor: UIColor? {
        get { return titleTextAttributes?[NSAttributedStringKey.foregroundColor] as? UIColor }
        set { titleTextAttributes?[NSAttributedStringKey.foregroundColor] = newValue }
    }

    var titleFont: UIFont? {
        get { return titleTextAttributes?[NSAttributedStringKey.font] as? UIFont }
        set { titleTextAttributes?[NSAttributedStringKey.font] = newValue }
    }

    open override func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "items":
            setItems(value as? [UINavigationItem], animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "backgroundImage":
            setBackgroundImage(value as? UIImage, for: .default)
        case "titleVerticalPositionAdjustment":
            setTitleVerticalPositionAdjustment(value as! CGFloat, for: .default)
        case "delegate":
            if viewController is UINavigationController {
                throw LayoutError("Cannot change the delegate of a UINavigationBar managed by a UINavigationController")
            }
            delegate = value as? UINavigationBarDelegate
        case "prefersLargeTitles":
            if #available(iOS 11.0, *) {
                fallthrough
            }
            // Does nothing on iOS 10 and earlier
        default:
            try _setValue(value, ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name)
        }
    }
}

extension UIToolbar {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["items"] = RuntimeType(Array<UIBarButtonItem>.self)
        types["backgroundImage"] = RuntimeType(UIImage.self)
        types["shadowImage"] = RuntimeType(UIImage.self)
        types["barStyle"] = barStyleType
        types["barPosition"] = barPositionType

        #if arch(i386) || arch(x86_64)
            // Private properties
            types["centerTextButtons"] = nil
        #endif
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "backgroundImage":
            setBackgroundImage(value as? UIImage, forToolbarPosition: .any, barMetrics: .default)
        case "shadowImage":
            setShadowImage(value as? UIImage, forToolbarPosition: .any)
        case "delegate":
            if viewController is UINavigationController {
                throw LayoutError("Cannot change the delegate of a UIToolbar managed by a UINavigationController")
            }
            fallthrough
        default:
            try _setValue(value, ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name)
        }
    }
}

extension UINavigationController {
    open override class func create(with node: LayoutNode) throws -> UINavigationController {
        var navigationBarClass = try node.value(forExpression: "navigationBarClass") as? UINavigationBar.Type
        var toolbarClass = try node.value(forExpression: "toolbarClass") as? UIToolbar.Type
        for child in node.children {
            if let cls = navigationBarClass, child._class is UINavigationBar.Type {
                if child._class.isSubclass(of: cls) {
                    navigationBarClass = child._class as? UINavigationBar.Type
                } else if !cls.isSubclass(of: child._class) {
                    throw LayoutError("\(child._class) is not compatible with \(cls)")
                }
            } else if let cls = toolbarClass, child._class is UIToolbar.Type {
                if child._class.isSubclass(of: cls) {
                    toolbarClass = child._class as? UIToolbar.Type
                } else if !cls.isSubclass(of: child._class) {
                    throw LayoutError("\(child._class) is not compatible with \(cls)")
                }
            }
        }
        return self.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return [
            "navigationBarClass": RuntimeType(class: UINavigationBar.self),
            "toolbarClass": RuntimeType(class: UIToolbar.self),
        ]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["viewControllers"] = RuntimeType(Array<UIViewController>.self)
        #if arch(i386) || arch(x86_64)
            // Private and read-only properties
            for name in [
                "allowUserInteractionDuringTransition",
                "avoidMovingNavBarOffscreenBeforeUnhiding",
                "condensesBarsOnSwipe",
                "customNavigationTransitionDuration",
                "detailViewController",
                "disappearingViewController",
                "enableBackButtonDuringTransition",
                "isExpanded",
                "isInteractiveTransition",
                "needsDeferredTransition",
                "pretendNavBarHidden",
            ] + [
                "navigationBar",
                "toolbar",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "isNavigationBarHidden":
            setNavigationBarHidden(value as! Bool, animated: true)
        case "isToolbarHidden":
            setToolbarHidden(value as! Bool, animated: true)
        case "viewControllers":
            setViewControllers(value as! [UIViewController], animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = node.viewController {
            var viewControllers = self.viewControllers
            viewControllers.append(viewController) // Ignore index
            self.viewControllers = viewControllers
        } else if node.viewClass is UINavigationBar.Type {
            assert(node._view == nil)
            node._view = navigationBar
        } else if node.viewClass is UIToolbar.Type {
            assert(node._view == nil)
            node._view = toolbar
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

// TODO: better support for alert actions and text fields
extension UIAlertController {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["preferredStyle"] = RuntimeType([
            "actionSheet": .actionSheet,
            "alert": .alert,
        ] as [String: UIAlertControllerStyle])
        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "contentViewController",
                "textFieldsCanBecomeFirstResponder",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }
}

extension UIActivityViewController {
    open override class func create(with node: LayoutNode) throws -> UIActivityViewController {
        let activityItems: [Any] = try node.value(forExpression: "activityItems") as? [Any] ?? []
        let applicationActivities = try node.value(forExpression: "applicationActivities") as? [UIActivity]
        return self.init(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return [
            "activityItems": RuntimeType([Any].self), // TODO: validate activity item types
            "applicationActivities": RuntimeType([UIActivity].self),
        ]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "activitiesByUUID",
                "activity",
                "activityAlertCancelAction",
                "activityAlertController",
                "activityItemProviderOperationQueue",
                "activityItemProviderOperations",
                "activityItems",
                "activityTypeOrder",
                "activityTypesToCreateInShareService",
                "activityViewController",
                "activityViewControllerConfiguration",
                "airDropDelegate",
                "allowsEmbedding",
                "applicationActivities",
                "backgroundTaskIdentifier",
                "completedProviderCount",
                "dismissalDetectionOfViewControllerForSelectedActivityShouldAutoCancel",
                "excludedActivityCategories",
                "extensionRequestIdentifier",
                "includedActivityTypes",
                "originalPopoverBackgroundStyle",
                "performActivityForStateRestoration",
                "preferredContentSizeWithoutSafeInsets",
                "preferredContentSizeWithoutSafeInsets.height",
                "preferredContentSizeWithoutSafeInsets.width",
                "shareExtension",
                "shareServicePreferredContentSizeIsValid",
                "shouldMatchOnlyUserElectedExtensions",
                "showKeyboardAutomatically",
                "sourceIsManaged",
                "subject",
                "totalProviderCount",
                "waitingForInitialShareServicePreferredContentSize",
                "willDismissActivityViewController",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }
}

extension UIImagePickerController {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["cameraCaptureMode"] = RuntimeType([
            "photo": .photo,
            "video": .video,
        ] as [String: UIImagePickerControllerCameraCaptureMode])
        types["cameraDevice"] = RuntimeType([
            "rear": .rear,
            "front": .front,
        ] as [String: UIImagePickerControllerCameraDevice])
        types["cameraFlashMode"] = RuntimeType([
            "off": .off,
            "auto": .auto,
            "on": .on,
        ] as [String: UIImagePickerControllerCameraFlashMode])
        types["imageExportPreset"] = RuntimeType([
            "compatible": IntOptionSet(rawValue: 1),
            "current": IntOptionSet(rawValue: 2),
        ] as [String: IntOptionSet])
        #if swift(>=3.2)
            if #available(iOS 11.0, *) {
                types["imageExportPreset"] = RuntimeType([
                    "compatible": .compatible,
                    "current": .current,
                ] as [String: UIImagePickerControllerImageURLExportPreset])
            }
        #endif
        types["sourceType"] = RuntimeType([
            "photoLibrary": .photoLibrary,
            "camera": .camera,
            "savedPhotosAlbum": .savedPhotosAlbum,
        ] as [String: UIImagePickerControllerSourceType])
        types["videoQuality"] = RuntimeType([
            "typeHigh": .typeHigh,
            "typeMedium": .typeMedium,
            "typeLow": .typeLow,
            "type640x480": .type640x480,
            "typeIFrame1280x720": .typeIFrame1280x720,
            "typeIFrame960x540": .typeIFrame960x540,
        ] as [String: UIImagePickerControllerQualityType])
        // TODO: validate media types
        // TODO: validate videoExportPreset
        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "allowsImageEditing",
                "initialViewControllerClassName",
                "photosExtension",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "imageExportPreset":
            if #available(iOS 11.0, *) {
                fallthrough
            }
            // Does nothing on iOS 10
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

extension UIInputViewController {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        #if arch(i386) || arch(x86_64)
            // Private property
            types["hasDictation"] = nil
        #endif
        return types
    }
}

extension UISplitViewController {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["preferredDisplayMode"] = RuntimeType([
            "automatic": .automatic,
            "primaryHidden": .primaryHidden,
            "allVisible": .allVisible,
            "primaryOverlay": .primaryOverlay,
        ] as [String: UISplitViewControllerDisplayMode])
        types["primaryEdge"] = RuntimeType([
            "leading": 0,
            "trailing": 1,
        ] as [String: Int])
        #if swift(>=3.2)
            if #available(iOS 11.0, *) {
                types["primaryEdge"] = RuntimeType([
                    "leading": .leading,
                    "trailing": .trailing,
                ] as [String: UISplitViewControllerPrimaryEdge])
            }
        #endif

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "gutterWidth",
                "hidesMasterViewInPortrait",
                "leadingViewController",
                "mainViewController",
                "masterColumnWidth",
                "stateRequest",
                "trailingViewController",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "primaryEdge":
            if #available(iOS 11.0, *) {
                fallthrough
            }
            // Does nothing on iOS 10 and earlier
        default:
            try _setValue(value, ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name)
        }
    }
}
