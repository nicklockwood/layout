//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

private var _cachedExpressionTypes = [Int: [String: RuntimeType]]()

extension UIView {

    /// The view controller that owns the view - used to access layout guides
    var viewController: UIViewController? {
        var controller: UIViewController?
        var responder: UIResponder? = next
        while responder != nil {
            if let responder = responder as? UIViewController {
                controller = responder
                break
            }
            responder = responder?.next
        }
        return controller
    }

    /// Expression names and types
    @objc open class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        // TODO: support more properties
        types["contentMode"] = RuntimeType(UIViewContentMode.self, [
            "scaleToFill": .scaleToFill,
            "scaleAspectFit": .scaleAspectFit,
            "scaleAspectFill": .scaleAspectFill,
            "redraw": .redraw,
            "center": .center,
            "top": .top,
            "bottom": .bottom,
            "left": .left,
            "right": .right,
            "topLeft": .topLeft,
            "topRight": .topRight,
            "bottomLeft": .bottomLeft,
            "bottomRight": .bottomRight,
        ] as [String: UIViewContentMode])
        types["tintAdjustmentMode"] = RuntimeType(UIViewTintAdjustmentMode.self, [
            "automatic": .automatic,
            "normal": .normal,
            "dimmed": .dimmed,
        ] as [String: UIViewTintAdjustmentMode])
        types["safeAreaInsets"] = RuntimeType(UIEdgeInsets.self, .readOnly)
        for key in ["top", "left", "bottom", "right"] {
            types["safeAreaInsets.\(key)"] = RuntimeType(CGFloat.self, .readOnly)
        }
        #if swift(>=3.2)
            if #available(iOS 11.0, *) {} else {
                types["directionalLayoutMargins"] = RuntimeType(UIEdgeInsets.self)
            }
        #else
            types["directionalLayoutMargins"] = RuntimeType(UIEdgeInsets.self)
        #endif
        for key in ["top", "leading", "bottom", "trailing"] {
            types["directionalLayoutMargins.\(key)"] = RuntimeType(CGFloat.self)
        }
        types["effectiveUserInterfaceLayoutDirection"] = RuntimeType(UIUserInterfaceLayoutDirection.self, .readOnly)
        for (name, type) in (layerClass as! CALayer.Type).cachedExpressionTypes {
            types["layer.\(name)"] = type
        }

        // Explicitly disabled properties
        for name in [
            "autoresizingMask",
            "bounds",
            "center",
            "frame",
            "frameOrigin",
            "origin",
            "position",
            "size",
            "topAnchor",
            "bottomAnchor",
            "leftAnchor",
            "rightAnchor",
            "widthAnchor",
            "heightAnchor",
            "leadingAnchor",
            "trailingAnchor",
            "centerXAnchor",
            "centerYAnchor",
        ] {
            types[name] = .unavailable("Use top/left/width/height expressions instead")
            let name = "\(name)."
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable("Use top/left/width/height expressions instead")
            }
        }
        for name in [
            "needsDisplayInRect",
            "layer.delegate",
        ] {
            types[name] = .unavailable()
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable()
            }
        }
        for name in [
            "allowsBaselineOffsetApproximation",
            "animationInfo",
            "charge",
            "clearsContext",
            "clipsSubviews",
            "compositingMode",
            "contentStretch",
            "contentsPosition",
            "customAlignmentRectInsets",
            "customBaselineOffsetFromBottom",
            "customFirstBaselineOffsetFromContentTop",
            "deliversButtonsForGesturesToSuperview",
            "deliversTouchesForGesturesToSuperview",
            "edgesInsettingLayoutMarginsFromSafeArea",
            "edgesPreservingSuperviewLayoutMargins",
            "enabledGestures",
            "fixedBackgroundPattern",
            "gesturesEnabled",
            "interactionTintColor",
            "invalidatingIntrinsicContentSizeAlsoInvalidatesSuperview",
            "isBaselineRelativeAlignmentRectInsets",
            "needsDisplayOnBoundsChange",
            "neverCacheContentLayoutSize",
            "previewingSegueTemplateStorage",
            "rotationBy",
            "skipsSubviewEnumeration",
            "viewTraversalMark",
            "wantsDeepColorDrawing",
        ] {
            types[name] = nil
            for key in types.keys where key.hasPrefix(name) {
                types[key] = nil
            }
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

    /// Constructor argument names and types
    @objc open class var parameterTypes: [String: RuntimeType] {
        return [:]
    }

    /// Called to construct the view
    @objc open class func create(with _: LayoutNode) throws -> UIView {
        return self.init()
    }

    private var _effectiveUserInterfaceLayoutDirection: UIUserInterfaceLayoutDirection {
        if #available(iOS 10.0, *) {
            return effectiveUserInterfaceLayoutDirection
        } else {
            return UIApplication.shared.userInterfaceLayoutDirection
        }
    }

    // Set expression value
    @objc open func setValue(_ value: Any, forExpression name: String) throws {
        if #available(iOS 11.0, *) {} else {
            let ltr = (_effectiveUserInterfaceLayoutDirection == .leftToRight)
            switch name {
            case "directionalLayoutMargins":
                layoutMargins = value as! UIEdgeInsets
                return
            case "directionalLayoutMargins.top":
                layoutMargins.top = value as! CGFloat
                return
            case "directionalLayoutMargins.leading":
                if ltr {
                    layoutMargins.left = value as! CGFloat
                } else {
                    layoutMargins.right = value as! CGFloat
                }
                return
            case "directionalLayoutMargins.bottom":
                layoutMargins.bottom = value as! CGFloat
                return
            case "directionalLayoutMargins.trailing":
                if ltr {
                    layoutMargins.right = value as! CGFloat
                } else {
                    layoutMargins.left = value as! CGFloat
                }
                return
            default:
                break
            }
        }
        try _setValue(value, ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name)
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
        if #available(iOS 11.0, *) {} else {
            let ltr = (_effectiveUserInterfaceLayoutDirection == .leftToRight)
            switch name {
            case "directionalLayoutMargins":
                return layoutMargins
            case "directionalLayoutMargins.top":
                return layoutMargins.top
            case "directionalLayoutMargins.leading":
                return ltr ? layoutMargins.left : layoutMargins.right
            case "directionalLayoutMargins.bottom":
                return layoutMargins.bottom
            case "directionalLayoutMargins.trailing":
                return ltr ? layoutMargins.right : layoutMargins.left
            case "effectiveUserInterfaceLayoutDirection":
                return _effectiveUserInterfaceLayoutDirection
            default:
                break
            }
        }
        return try _value(ofType: type(of: self).cachedExpressionTypes[name], forKeyPath: name) as Any
    }

    /// Called immediately after a child node is added
    @objc open func didInsertChildNode(_ node: LayoutNode, at _: Int) {
        if let viewController = self.viewController {
            for controller in node.viewControllers {
                viewController.addChildViewController(controller)
            }
        }
        addSubview(node.view) // Ignore index
    }

    /// Called immediately before a child node is removed
    // TODO: remove index argument as it isn't used
    @objc open func willRemoveChildNode(_ node: LayoutNode, at _: Int) {
        if node._view == nil { return }
        for controller in node.viewControllers {
            controller.removeFromParentViewController()
        }
        node.view.removeFromSuperview()
    }

    /// Called immediately after layout has been performed
    @objc open func didUpdateLayout(for _: LayoutNode) {}
}

private let controlEvents: [String: UIControlEvents] = [
    "touchDown": .touchDown,
    "touchDownRepeat": .touchDownRepeat,
    "touchDragInside": .touchDragInside,
    "touchDragOutside": .touchDragOutside,
    "touchDragEnter": .touchDragEnter,
    "touchDragExit": .touchDragExit,
    "touchUpInside": .touchUpInside,
    "touchUpOutside": .touchUpOutside,
    "touchCancel": .touchCancel,
    "valueChanged": .valueChanged,
    "primaryActionTriggered": .primaryActionTriggered,
    "editingDidBegin": .editingDidBegin,
    "editingChanged": .editingChanged,
    "editingDidEnd": .editingDidEnd,
    "editingDidEndOnExit": .editingDidEndOnExit,
    "allTouchEvents": .allTouchEvents,
    "allEditingEvents": .allEditingEvents,
    "allEvents": .allEvents,
]

private let controlStates: [String: UIControlState] = [
    "normal": .normal,
    "highlighted": .highlighted,
    "disabled": .disabled,
    "selected": .selected,
    "focused": .focused,
]

private var layoutActionsKey: UInt8 = 0
extension UIControl {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["contentVerticalAlignment"] = RuntimeType(UIControlContentVerticalAlignment.self, [
            "center": .center,
            "top": .top,
            "bottom": .bottom,
            "fill": .fill,
        ] as [String: UIControlContentVerticalAlignment])
        types["contentHorizontalAlignment"] = RuntimeType(UIControlContentHorizontalAlignment.self, [
            "center": .center,
            "left": .left,
            "right": .right,
            "fill": .fill,
        ] as [String: UIControlContentHorizontalAlignment])
        for name in controlEvents.keys {
            types[name] = RuntimeType(Selector.self)
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        if let action = value as? Selector, let event = controlEvents[name] {
            var actions = objc_getAssociatedObject(self, &layoutActionsKey) as? NSMutableDictionary
            if actions == nil {
                actions = NSMutableDictionary()
                objc_setAssociatedObject(self, &layoutActionsKey, actions, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            if let oldAction = actions?[name] as? Selector {
                if oldAction == action {
                    return
                }
                removeTarget(nil, action: action, for: event)
            }
            actions?[name] = action
            return
        }
        try super.setValue(value, forExpression: name)
    }

    func bindActions(for target: AnyObject) throws {
        guard let actions = objc_getAssociatedObject(self, &layoutActionsKey) as? NSMutableDictionary else {
            return
        }
        for (name, action) in actions {
            guard let name = name as? String, let event = controlEvents[name], let action = action as? Selector else {
                assertionFailure()
                return
            }
            if let actions = self.actions(forTarget: target, forControlEvent: event), actions.contains("\(action)") {
                // Already bound
            } else {
                if !target.responds(to: action) {
                    throw LayoutError.message("\(target.classForCoder ?? type(of: target)) does not respond to \(action).\n\nIf the method exists, it must be prefixed with @objc or @IBAction to be used with Layout")
                }
                addTarget(target, action: action, for: event)
            }
        }
    }

    func unbindActions(for target: AnyObject) {
        for action in actions(forTarget: target, forControlEvent: .allEvents) ?? [] {
            removeTarget(target, action: Selector(action), for: .allEvents)
        }
    }
}

extension UIButton {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["type"] = RuntimeType(UIButtonType.self, [
            "custom": .custom,
            "system": .system,
            "detailDisclosure": .detailDisclosure,
            "infoLight": .infoLight,
            "infoDark": .infoDark,
            "contactAdd": .contactAdd,
        ] as [String: UIButtonType])
        types["buttonType"] = types["type"]
        types["title"] = RuntimeType(String.self)
        for state in controlStates.keys {
            types["\(state)Title"] = RuntimeType(String.self)
        }
        types["attributedTitle"] = RuntimeType(NSAttributedString.self)
        for state in controlStates.keys {
            types["\(state)AttributedTitle"] = RuntimeType(NSAttributedString.self)
        }
        types["titleColor"] = RuntimeType(UIColor.self)
        for state in controlStates.keys {
            types["\(state)TitleColor"] = RuntimeType(UIColor.self)
        }
        types["titleShadowColor"] = RuntimeType(UIColor.self)
        for state in controlStates.keys {
            types["\(state)TitleShadowColor"] = RuntimeType(UIColor.self)
        }
        for (name, type) in UILabel.cachedExpressionTypes {
            types["titleLabel.\(name)"] = type
        }
        types["image"] = RuntimeType(UIImage.self)
        for state in controlStates.keys {
            types["\(state)Image"] = RuntimeType(UIImage.self)
        }
        for (name, type) in UIImageView.cachedExpressionTypes {
            types["imageView.\(name)"] = type
        }
        types["backgroundImage"] = RuntimeType(UIImage.self)
        for state in controlStates.keys {
            types["\(state)BackgroundImage"] = RuntimeType(UIImage.self)
        }
        // Setters used for embedded html
        types["text"] = RuntimeType(String.self)
        types["attributedText"] = RuntimeType(NSAttributedString.self)
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "type", "buttonType": setValue((value as! UIButtonType).rawValue, forKey: "buttonType")
        case "title": setTitle(value as? String, for: .normal)
        case "titleColor": setTitleColor(value as? UIColor, for: .normal)
        case "titleShadowColor": setTitleShadowColor(value as? UIColor, for: .normal)
        case "image": setImage(value as? UIImage, for: .normal)
        case "backgroundImage": setBackgroundImage(value as? UIImage, for: .normal)
        case "attributedTitle": setAttributedTitle(value as? NSAttributedString, for: .normal)
        case "text": setTitle(value as? String, for: .normal)
        case "attributedText": setAttributedTitle(value as? NSAttributedString, for: .normal)
        default:
            if let (prefix, state) = controlStates.first(where: { name.hasPrefix($0.key) }) {
                switch name[prefix.endIndex ..< name.endIndex] {
                case "Title": setTitle(value as? String, for: state)
                case "TitleColor": setTitleColor(value as? UIColor, for: state)
                case "TitleShadowColor": setTitleShadowColor(value as? UIColor, for: state)
                case "Image": setImage(value as? UIImage, for: state)
                case "BackgroundImage":setBackgroundImage(value as? UIImage, for: state)
                case "AttributedTitle": setAttributedTitle(value as? NSAttributedString, for: state)
                default:
                    break
                }
                return
            }
            try super.setValue(value, forExpression: name)
        }
    }
}

private let textInputTraits: [String: RuntimeType] = {
    var keyboardTypes: [String: UIKeyboardType] = [
        "default": .default,
        "asciiCapable": .asciiCapable,
        "numbersAndPunctuation": .numbersAndPunctuation,
        "URL": .URL,
        "url": .URL,
        "numberPad": .numberPad,
        "phonePad": .phonePad,
        "namePhonePad": .namePhonePad,
        "emailAddress": .emailAddress,
        "decimalPad": .decimalPad,
        "twitter": .twitter,
        "webSearch": .webSearch,
    ]
    if #available(iOS 10.0, *) {
        keyboardTypes["asciiCapableNumberPad"] = .asciiCapableNumberPad
    } else {
        // TODO: show warning?
        keyboardTypes["asciiCapableNumberPad"] = .asciiCapable
    }
    var traitTypes = [
        "autocapitalizationType": RuntimeType(UITextAutocapitalizationType.self, [
            "none": .none,
            "words": .words,
            "sentences": .sentences,
            "allCharacters": .allCharacters,
        ] as [String: UITextAutocapitalizationType]),
        "autocorrectionType": RuntimeType(UITextAutocorrectionType.self, [
            "default": .default,
            "no": .no,
            "yes": .yes,
        ] as [String: UITextAutocorrectionType]),
        "spellCheckingType": RuntimeType(UITextSpellCheckingType.self, [
            "default": .default,
            "no": .no,
            "yes": .yes,
        ] as [String: UITextSpellCheckingType]),
        "keyboardType": RuntimeType(UIKeyboardType.self, keyboardTypes),
        "keyboardAppearance": RuntimeType(UIKeyboardAppearance.self, [
            "default": .default,
            "dark": .dark,
            "light": .light,
        ] as [String: UIKeyboardAppearance]),
        "returnKeyType": RuntimeType(UIReturnKeyType.self, [
            "default": .default,
            "go": .go,
            "google": .google,
            "join": .join,
            "next": .next,
            "route": .route,
            "search": .search,
            "send": .send,
            "yahoo": .yahoo,
            "done": .done,
            "emergencyCall": .emergencyCall,
            "continue": .continue,
        ] as [String: UIReturnKeyType]),
        "enablesReturnKeyAutomatically": RuntimeType(Bool.self),
        "isSecureTextEntry": RuntimeType(Bool.self),
    ]

    for key in ["smartQuotesType", "smartDashesType", "smartInsertDeleteType"] {
        traitTypes[key] = RuntimeType(Int.self, [
            "default": 0,
            "no": 1,
            "yes": 2,
        ] as [String: Int])
    }
    #if swift(>=3.2)
        if #available(iOS 11.0, *) {
            traitTypes["smartQuotesType"] = RuntimeType(UITextSmartQuotesType.self, [
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartQuotesType])
            traitTypes["smartDashesType"] = RuntimeType(UITextSmartDashesType.self, [
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartDashesType])
            traitTypes["smartInsertDeleteType"] = RuntimeType(UITextSmartInsertDeleteType.self, [
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartInsertDeleteType])
        }
    #endif

    return traitTypes
}()

private let textTraits = [
    "textAlignment": RuntimeType(NSTextAlignment.self, [
        "left": .left,
        "right": .right,
        "center": .center,
    ] as [String: NSTextAlignment]),
    "lineBreakMode": RuntimeType(NSLineBreakMode.self, [
        "byWordWrapping": .byWordWrapping,
        "byCharWrapping": .byCharWrapping,
        "byClipping": .byClipping,
        "byTruncatingHead": .byTruncatingHead,
        "byTruncatingTail": .byTruncatingTail,
        "byTruncatingMiddle": .byTruncatingMiddle,
    ] as [String: NSLineBreakMode]),
]

extension UILabel {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textTraits {
            types[name] = type
        }
        types["baselineAdjustment"] = RuntimeType(UIBaselineAdjustment.self, [
            "alignBaselines": .alignBaselines,
            "alignCenters": .alignCenters,
            "none": .none,
        ] as [String: UIBaselineAdjustment])
        return types
    }
}

private let textFieldViewMode = RuntimeType(UITextFieldViewMode.self, [
    "never": .never,
    "whileEditing": .whileEditing,
    "unlessEditing": .unlessEditing,
    "always": .always,
] as [String: UITextFieldViewMode])

extension UITextField {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textInputTraits {
            types[name] = type
        }
        for (name, type) in textTraits {
            types[name] = type
        }
        types["borderStyle"] = RuntimeType(UITextBorderStyle.self, [
            "none": .none,
            "line": .line,
            "bezel": .bezel,
            "roundedRect": .roundedRect,
        ] as [String: UITextBorderStyle])
        types["clearButtonMode"] = textFieldViewMode
        types["leftViewMode"] = textFieldViewMode
        types["rightViewMode"] = textFieldViewMode
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "autocapitalizationType": autocapitalizationType = value as! UITextAutocapitalizationType
        case "autocorrectionType": autocorrectionType = value as! UITextAutocorrectionType
        case "spellCheckingType": spellCheckingType = value as! UITextSpellCheckingType
        case "keyboardType": keyboardType = value as! UIKeyboardType
        case "keyboardAppearance": keyboardAppearance = value as! UIKeyboardAppearance
        case "returnKeyType": returnKeyType = value as! UIReturnKeyType
        case "enablesReturnKeyAutomatically": enablesReturnKeyAutomatically = value as! Bool
        case "isSecureTextEntry": isSecureTextEntry = value as! Bool
        case "smartQuotesType":
            #if swift(>=3.2)
                if #available(iOS 11.0, *) {
                    smartQuotesType = value as! UITextSmartQuotesType
                }
            #endif
            // TODO: warn about unavailability
        case "smartDashesType":
            #if swift(>=3.2)
                if #available(iOS 11.0, *) {
                    smartDashesType = value as! UITextSmartDashesType
                }
            #endif
            // TODO: warn about unavailability
        case "smartInsertDeleteType":
            #if swift(>=3.2)
                if #available(iOS 11.0, *) {
                    smartInsertDeleteType = value as! UITextSmartInsertDeleteType
                }
            #endif
            // TODO: warn about unavailability
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

extension UITextView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textInputTraits {
            types[name] = type
        }
        for (name, type) in textTraits {
            types[name] = type
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "autocapitalizationType": autocapitalizationType = value as! UITextAutocapitalizationType
        case "autocorrectionType": autocorrectionType = value as! UITextAutocorrectionType
        case "spellCheckingType": spellCheckingType = value as! UITextSpellCheckingType
        case "keyboardType": keyboardType = value as! UIKeyboardType
        case "keyboardAppearance": keyboardAppearance = value as! UIKeyboardAppearance
        case "returnKeyType": returnKeyType = value as! UIReturnKeyType
        case "enablesReturnKeyAutomatically": enablesReturnKeyAutomatically = value as! Bool
        case "isSecureTextEntry": isSecureTextEntry = value as! Bool
        case "smartQuotesType":
            #if swift(>=3.2)
                if #available(iOS 11.0, *) {
                    smartQuotesType = value as! UITextSmartQuotesType
                }
            #endif
            // TODO: warn about unavailability
        case "smartDashesType":
            #if swift(>=3.2)
                if #available(iOS 11.0, *) {
                    smartDashesType = value as! UITextSmartDashesType
                }
            #endif
            // TODO: warn about unavailability
        case "smartInsertDeleteType":
            #if swift(>=3.2)
                if #available(iOS 11.0, *) {
                    smartInsertDeleteType = value as! UITextSmartInsertDeleteType
                }
            #endif
            // TODO: warn about unavailability
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

private let controlSegments: [String: UISegmentedControlSegment] = [
    "any": .any,
    "left": .left,
    "center": .center,
    "right": .right,
    "alone": .alone,
]

extension UISegmentedControl: TitleTextAttributes {
    open override class func create(with node: LayoutNode) throws -> UISegmentedControl {
        var items = [Any]()
        for item in try node.value(forExpression: "items") as? [Any] ?? [] {
            switch item {
            case is String, is UIImage:
                items.append(item)
            default:
                throw LayoutError("\(type(of: item)) is not a valid item type for \(classForCoder())", for: node)
            }
        }
        return self.init(items: items)
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["items"] = RuntimeType(NSArray.self)
        types["backgroundImage"] = RuntimeType(UIImage.self)
        for state in controlStates.keys {
            types["\(state)BackgroundImage"] = RuntimeType(UIImage.self)
        }
        types["dividerImage"] = RuntimeType(UIImage.self)
        // TODO: find a good naming scheme for left/right state variants
        types["titleColor"] = RuntimeType(UIColor.self)
        for state in controlStates.keys {
            types["\(state)TitleColor"] = RuntimeType(UIColor.self)
        }
        types["titleFont"] = RuntimeType(UIFont.self)
        for state in controlStates.keys {
            types["\(state)TitleFont"] = RuntimeType(UIFont.self)
        }
        types["contentPositionAdjustment"] = RuntimeType(UIOffset.self)
        types["contentPositionAdjustment.horizontal"] = RuntimeType(CGFloat.self)
        types["contentPositionAdjustment.vertical"] = RuntimeType(CGFloat.self)
        for segment in controlSegments.keys {
            types["\(segment)ContentPositionAdjustment"] = RuntimeType(UIOffset.self)
            types["\(segment)ContentPositionAdjustment.horizontal"] = RuntimeType(CGFloat.self)
            types["\(segment)ContentPositionAdjustment.vertical"] = RuntimeType(CGFloat.self)
        }
        return types
    }

    private func setItems(_ items: NSArray?, animated: Bool) throws {
        let items = items ?? []
        for (i, item) in items.enumerated() {
            switch item {
            case let title as String:
                if i >= numberOfSegments {
                    insertSegment(withTitle: title, at: i, animated: animated)
                } else {
                    if let oldTitle = titleForSegment(at: i), oldTitle == title {
                        break
                    }
                    removeSegment(at: i, animated: animated)
                    insertSegment(withTitle: title, at: i, animated: animated)
                }
            case let image as UIImage:
                if i >= numberOfSegments {
                    insertSegment(with: image, at: i, animated: animated)
                } else {
                    if let oldImage = imageForSegment(at: i), oldImage == image {
                        break
                    }
                    removeSegment(at: i, animated: animated)
                    insertSegment(with: image, at: i, animated: animated)
                }
            default:
                throw SymbolError("items array may only contain Strings or UIImages", for: "items")
            }
        }
        while items.count > numberOfSegments {
            removeSegment(at: numberOfSegments - 1, animated: animated)
        }
    }

    var titleColor: UIColor? {
        get { return titleTextAttributes(for: .normal)?[NSAttributedStringKey.foregroundColor] as? UIColor }
        set { setTitleColor(newValue, for: .normal) }
    }

    var titleFont: UIFont? {
        get { return titleTextAttributes(for: .normal)?[NSAttributedStringKey.font] as? UIFont }
        set { setTitleFont(newValue, for: .normal) }
    }

    private func setTitleColor(_ color: UIColor?, for state: UIControlState) {
        var attributes = titleTextAttributes(for: state) ?? [:]
        attributes[NSAttributedStringKey.foregroundColor] = color
        setTitleTextAttributes(attributes, for: state)
    }

    private func setTitleFont(_ font: UIFont?, for state: UIControlState) {
        var attributes = titleTextAttributes(for: state) ?? [:]
        attributes[NSAttributedStringKey.font] = font
        setTitleTextAttributes(attributes, for: state)
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "items": try setItems(value as? NSArray, animated: false)
            // TODO: find a good naming scheme for barMetrics variants
        case "backgroundImage": setBackgroundImage(value as? UIImage, for: .normal, barMetrics: .default)
        case "dividerImage": setDividerImage(value as? UIImage, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        case "titleColor": setTitleColor(value as? UIColor, for: .normal)
        case "titleFont": setTitleFont(value as? UIFont, for: .normal)
        case "contentPositionAdjustment": setContentPositionAdjustment(value as! UIOffset, forSegmentType: .any, barMetrics: .default)
        case "contentPositionAdjustment.horizontal":
            var offset = contentPositionAdjustment(forSegmentType: .any, barMetrics: .default)
            offset.horizontal = value as! CGFloat
            setContentPositionAdjustment(offset, forSegmentType: .any, barMetrics: .default)
        case "contentPositionAdjustment.vertical":
            var offset = contentPositionAdjustment(forSegmentType: .any, barMetrics: .default)
            offset.vertical = value as! CGFloat
            setContentPositionAdjustment(offset, forSegmentType: .any, barMetrics: .default)
        default:
            if let (prefix, state) = controlStates.first(where: { name.hasPrefix($0.key) }) {
                switch name[prefix.endIndex ..< name.endIndex] {
                case "BackgroundImage": setBackgroundImage(value as? UIImage, for: state, barMetrics: .default)
                case "TitleColor": setTitleColor(value as? UIColor, for: state)
                case "TitleFont": setTitleFont(value as? UIFont, for: state)
                default:
                    try super.setValue(value, forExpression: name)
                }
                return
            }
            if let (prefix, segment) = controlSegments.first(where: { name.hasPrefix($0.key) }) {
                switch name[prefix.endIndex ..< name.endIndex] {
                case "ContentPositionAdjustment":
                    setContentPositionAdjustment(value as! UIOffset, forSegmentType: segment, barMetrics: .default)
                case "ContentPositionAdjustment.horizontal":
                    var offset = contentPositionAdjustment(forSegmentType: segment, barMetrics: .default)
                    offset.horizontal = value as! CGFloat
                    setContentPositionAdjustment(offset, forSegmentType: segment, barMetrics: .default)
                case "ContentPositionAdjustment.vertical":
                    var offset = contentPositionAdjustment(forSegmentType: segment, barMetrics: .default)
                    offset.vertical = value as! CGFloat
                    setContentPositionAdjustment(offset, forSegmentType: segment, barMetrics: .default)
                default:
                    try super.setValue(value, forExpression: name)
                }
                return
            }
            try super.setValue(value, forExpression: name)
        }
    }

    open override func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "items":
            try setItems(value as? NSArray, animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }
}

let barStyleType = RuntimeType(UIBarStyle.self, [
    "default": .default,
    "black": .black,
])

let barPositionType = RuntimeType(UIBarPosition.self, [
    "any": .any,
    "bottom": .bottom,
    "top": .top,
    "topAttached": .topAttached,
])

extension UISearchBar {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["barStyle"] = barStyleType
        types["barPosition"] = barPositionType
        types["searchBarStyle"] = RuntimeType(UISearchBarStyle.self, [
            "default": .default,
            "prominent": .prominent,
            "minimal": .minimal,
        ] as [String: UISearchBarStyle])
        // TODO: more properties
        return types
    }
}

extension UIStepper {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["backgroundImage"] = RuntimeType(UIImage.self)
        for state in controlStates.keys {
            types["\(state)BackgroundImage"] = RuntimeType(UIImage.self)
        }
        types["dividerImage"] = RuntimeType(UIImage.self)
        // TODO: find a good naming scheme for left/right state variants
        types["incrementImage"] = RuntimeType(UIColor.self)
        for state in controlStates.keys {
            types["\(state)IncrementImage"] = RuntimeType(UIImage.self)
        }
        types["decrementImage"] = RuntimeType(UIFont.self)
        for state in controlStates.keys {
            types["\(state)DecrementImage"] = RuntimeType(UIImage.self)
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "backgroundImage": setBackgroundImage(value as? UIImage, for: .normal)
        case "dividerImage": setDividerImage(value as? UIImage, forLeftSegmentState: .normal, rightSegmentState: .normal)
        case "incrementImage": setIncrementImage(value as? UIImage, for: .normal)
        case "decrementImage": setDecrementImage(value as? UIImage, for: .normal)
        default:
            if let (prefix, state) = controlStates.first(where: { name.hasPrefix($0.key) }) {
                switch name[prefix.endIndex ..< name.endIndex] {
                case "BackgroundImage": setBackgroundImage(value as? UIImage, for: state)
                case "IncrementImage": setIncrementImage(value as? UIImage, for: state)
                case "DecrementImage": setDecrementImage(value as? UIImage, for: state)
                default:
                    try super.setValue(value, forExpression: name)
                }
                return
            }
            try super.setValue(value, forExpression: name)
        }
    }
}
