//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import WebKit

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
        types["alpha"] = RuntimeType(CGFloat.self)
        types["contentScaleFactor"] = RuntimeType(CGFloat.self)
        types["contentMode"] = RuntimeType([
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
        types["tintAdjustmentMode"] = RuntimeType([
            "automatic": .automatic,
            "normal": .normal,
            "dimmed": .dimmed,
        ] as [String: UIViewTintAdjustmentMode])
        if #available(iOS 11.0, *) {} else {
            types["directionalLayoutMargins"] = RuntimeType(UIEdgeInsets.self)
        }
        for key in ["top", "leading", "bottom", "trailing"] {
            types["directionalLayoutMargins.\(key)"] = RuntimeType(CGFloat.self)
        }
        types["semanticContentAttribute"] = RuntimeType([
            "unspecified": .unspecified,
            "playback": .playback,
            "spatial": .spatial,
            "forceLeftToRight": .forceLeftToRight,
            "forceRightToLeft": .forceRightToLeft,
        ] as [String: UISemanticContentAttribute])
        for (name, type) in (layerClass as! CALayer.Type).cachedExpressionTypes {
            types["layer.\(name)"] = type
        }

        // Explicitly disabled properties
        for name in [
            "autoresizingMask",
            "bounds",
            "center",
            "frame",
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
            let name = "\(name)."
            for key in types.keys where key.hasPrefix(name) {
                types[key] = .unavailable()
            }
        }

        #if arch(i386) || arch(x86_64)
            // Private and read-only properties
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
                "frameOrigin",
                "gesturesEnabled",
                "interactionTintColor",
                "invalidatingIntrinsicContentSizeAlsoInvalidatesSuperview",
                "isBaselineRelativeAlignmentRectInsets",
                "needsDisplayOnBoundsChange",
                "neverCacheContentLayoutSize",
                "origin",
                "position",
                "previewingSegueTemplateStorage",
                "rotationBy",
                "size",
                "skipsSubviewEnumeration",
                "viewTraversalMark",
                "wantsDeepColorDrawing",
            ] + [
                "effectiveUserInterfaceLayoutDirection",
                "safeAreaInsets",
            ] {
                types[name] = nil
                let name = "\(name)."
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif
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

    /// Default expressions to use when not specified
    @objc open class var defaultExpressions: [String: String] {
        return [:]
    }

    // Return the best available VC for computing the layout guide
    var _layoutGuideController: UIViewController? {
        let viewController = self.viewController
        return viewController?.navigationController?.topViewController ??
            viewController?.tabBarController?.selectedViewController ?? viewController
    }

    var _safeAreaInsets: UIEdgeInsets {
        #if swift(>=3.2)
            if #available(iOS 11.0, *), let viewController = viewController {
                // This is the root view of a controller, so we can use the inset value directly, as per
                // https://developer.apple.com/documentation/uikit/uiview/2891103-safeareainsets
                return viewController.view.safeAreaInsets
            }
        #endif
        return UIEdgeInsets(
            top: _layoutGuideController?.topLayoutGuide.length ?? 0,
            left: 0,
            bottom: _layoutGuideController?.bottomLayoutGuide.length ?? 0,
            right: 0
        )
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
            case "layer.maskedCorners":
                return // TODO: warn about unavailability
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
        switch name {
        case "safeAreaInsets":
            return _safeAreaInsets
        case "safeAreaInsets.top":
            return _safeAreaInsets.top
        case "safeAreaInsets.left":
            return _safeAreaInsets.left
        case "safeAreaInsets.bottom":
            return _safeAreaInsets.bottom
        case "safeAreaInsets.right":
            return _safeAreaInsets.right
        case "topLayoutGuide.length": // TODO: deprecate this
            return _layoutGuideController?.topLayoutGuide.length ?? 0
        case "bottomLayoutGuide.length": // TODO: deprecate this
            return _layoutGuideController?.bottomLayoutGuide.length ?? 0
        default:
            break
        }
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

extension UIImageView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "adjustsImageWhenAncestorFocused",
                "cGImageRef",
                "drawMode",
                "masksFocusEffectToContents",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "isAnimating":
            switch (value as! Bool, isAnimating) {
            case (true, false):
                startAnimating()
            case (false, true):
                stopAnimating()
            case (true, true), (false, false):
                break
            }
        default:
            try super.setValue(value, forExpression: name)
        }
    }
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
        types["contentVerticalAlignment"] = RuntimeType([
            "center": .center,
            "top": .top,
            "bottom": .bottom,
            "fill": .fill,
        ] as [String: UIControlContentVerticalAlignment])
        types["contentHorizontalAlignment"] = RuntimeType([
            "center": .center,
            "left": .left,
            "right": .right,
            "fill": .fill,
        ] as [String: UIControlContentHorizontalAlignment])
        for name in controlEvents.keys {
            types[name] = RuntimeType(Selector.self)
        }

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "adPrivacyData",
                "requiresDisplayOnTracking",
            ] {
                types[name] = nil
            }
        #endif
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
                    guard let responder = target as? UIResponder, let next = responder.next else {
                        throw LayoutError.message("Layout could find no suitable target for the `\(action)` action. If the method exists, it must be prefixed with @objc or @IBAction to be used with Layout")
                    }
                    try bindActions(for: next)
                    return
                }
                addTarget(target, action: action, for: event)
            }
        }
    }

    func unbindActions(for target: AnyObject) {
        for action in actions(forTarget: target, forControlEvent: .allEvents) ?? [] {
            removeTarget(target, action: Selector(action), for: .allEvents)
        }
        if let responder = target as? UIResponder, let next = responder.next {
            unbindActions(for: next)
        }
    }
}

private let _buttonType = RuntimeType([
    "custom": .custom,
    "system": .system,
    "detailDisclosure": .detailDisclosure,
    "infoLight": .infoLight,
    "infoDark": .infoDark,
    "contactAdd": .contactAdd,
] as [String: UIButtonType])

extension UIButton {
    open override class func create(with node: LayoutNode) throws -> UIButton {
        if let type = try node.value(forExpression: "type") as? UIButtonType {
            return self.init(type: type)
        }
        return self.init(frame: .zero)
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return ["type": _buttonType]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["title"] = RuntimeType(String.self)
        types["attributedTitle"] = RuntimeType(NSAttributedString.self)
        types["titleColor"] = RuntimeType(UIColor.self)
        types["titleShadowColor"] = RuntimeType(UIColor.self)
        types["image"] = RuntimeType(UIImage.self)
        types["backgroundImage"] = RuntimeType(UIImage.self)
        for state in controlStates.keys {
            types["\(state)Title"] = RuntimeType(String.self)
            types["\(state)AttributedTitle"] = RuntimeType(NSAttributedString.self)
            types["\(state)TitleColor"] = RuntimeType(UIColor.self)
            types["\(state)TitleShadowColor"] = RuntimeType(UIColor.self)
            types["\(state)Image"] = RuntimeType(UIImage.self)
            types["\(state)BackgroundImage"] = RuntimeType(UIImage.self)
        }
        for (name, type) in UILabel.cachedExpressionTypes {
            types["titleLabel.\(name)"] = type
        }
        for (name, type) in UIImageView.cachedExpressionTypes {
            types["imageView.\(name)"] = type
        }
        // Setters used for embedded html
        types["text"] = RuntimeType(String.self)
        types["attributedText"] = RuntimeType(NSAttributedString.self)

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "autosizesToFit",
                "lineBreakMode",
                "showPressFeedback",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
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
        "autocapitalizationType": RuntimeType([
            "none": .none,
            "words": .words,
            "sentences": .sentences,
            "allCharacters": .allCharacters,
        ] as [String: UITextAutocapitalizationType]),
        "autocorrectionType": RuntimeType([
            "default": .default,
            "no": .no,
            "yes": .yes,
        ] as [String: UITextAutocorrectionType]),
        "spellCheckingType": RuntimeType([
            "default": .default,
            "no": .no,
            "yes": .yes,
        ] as [String: UITextSpellCheckingType]),
        "keyboardType": RuntimeType(keyboardTypes),
        "keyboardAppearance": RuntimeType([
            "default": .default,
            "dark": .dark,
            "light": .light,
        ] as [String: UIKeyboardAppearance]),
        "returnKeyType": RuntimeType([
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
        traitTypes[key] = RuntimeType([
            "default": 0,
            "no": 1,
            "yes": 2,
        ] as [String: Int])
    }
    #if swift(>=3.2)
        if #available(iOS 11.0, *) {
            traitTypes["smartQuotesType"] = RuntimeType([
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartQuotesType])
            traitTypes["smartDashesType"] = RuntimeType([
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartDashesType])
            traitTypes["smartInsertDeleteType"] = RuntimeType([
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartInsertDeleteType])
        }
    #endif

    return traitTypes
}()

private let textAlignmentType = RuntimeType([
    "left": .left,
    "right": .right,
    "center": .center,
] as [String: NSTextAlignment])

private let lineBreakModeType = RuntimeType([
    "byWordWrapping": .byWordWrapping,
    "byCharWrapping": .byCharWrapping,
    "byClipping": .byClipping,
    "byTruncatingHead": .byTruncatingHead,
    "byTruncatingTail": .byTruncatingTail,
    "byTruncatingMiddle": .byTruncatingMiddle,
] as [String: NSLineBreakMode])

extension UILabel {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["textAlignment"] = textAlignmentType
        types["lineBreakMode"] = lineBreakModeType
        types["baselineAdjustment"] = RuntimeType([
            "alignBaselines": .alignBaselines,
            "alignCenters": .alignCenters,
            "none": .none,
        ] as [String: UIBaselineAdjustment])

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "adjustsLetterSpacingToFitWidth",
                "autotrackTextToFit",
                "centersHorizontally",
                "color",
                "drawsLetterpress",
                "drawsUnderline",
                "lineSpacing",
                "marqueeEnabled",
                "marqueeRunning",
                "minimumFontSize",
                "rawSize",
                "rawSize.width",
                "rawSize.height",
                "shadowBlur",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }
}

private let textFieldViewMode = RuntimeType([
    "never": .never,
    "whileEditing": .whileEditing,
    "unlessEditing": .unlessEditing,
    "always": .always,
] as [String: UITextFieldViewMode])

private let dragAndDropOptions: [String: RuntimeType] = {
    var types: [String: RuntimeType] = [
        "textDragDelegate": RuntimeType(Any.self),
        "textDropDelegate": RuntimeType(Any.self),
        "textDragOptions": RuntimeType([
            "stripTextColorFromPreviews": IntOptionSet(rawValue: 1),
        ] as [String: IntOptionSet]),
    ]
    #if swift(>=3.2)
        if #available(iOS 11.0, *) {
            types["textDragDelegate"] = RuntimeType(UITextDragDelegate.self)
            types["textDropDelegate"] = RuntimeType(UITextDropDelegate.self)
            types["textDragOptions"] = RuntimeType([
                "stripTextColorFromPreviews": .stripTextColorFromPreviews,
            ] as [String: UITextDragOptions])
        }
    #endif
    return types
}()

extension UITextField {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textInputTraits {
            types[name] = type
        }
        types["textAlignment"] = textAlignmentType
        types["borderStyle"] = RuntimeType([
            "none": .none,
            "line": .line,
            "bezel": .bezel,
            "roundedRect": .roundedRect,
        ] as [String: UITextBorderStyle])
        types["clearButtonMode"] = textFieldViewMode
        types["leftViewMode"] = textFieldViewMode
        types["rightViewMode"] = textFieldViewMode
        types["minimumFontSize"] = RuntimeType(CGFloat.self)
        for (name, type) in dragAndDropOptions {
            types[name] = type
        }

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "animating",
                "atomStyle",
                "autoresizesTextToFit",
                "becomesFirstResponderOnClearButtonTap",
                "clearButtonOffset",
                "clearButtonStyle",
                "clearingBehavior",
                "clearsPlaceholderOnBeginEditing",
                "contentOffsetForSameViewDrops",
                "continuousSpellCheckingEnabled",
                "defaultTextAttributes",
                "displaySecureEditsUsingPlainText",
                "displaySecureTextUsingPlainText",
                "drawsAsAtom",
                "inactiveHasDimAppearance",
                "isUndoEnabled",
                "labelOffset",
                "nonEditingLinebreakMode",
                "paddingBottom",
                "paddingLeft",
                "paddingRight",
                "paddingTop",
                "progress",
                "recentsAccessoryView",
                "selectionRange",
                "shadowBlur",
                "shadowColor",
                "shadowOffset",
                "textAutorresizesToFit",
                "textCentersHorizontally",
                "textCentersVertically",
                "textSelectionBehavior",
            ] {
                types[name] = nil
                let name = "\(name)."
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif
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
        case "textDragDelegate", "textDropDelegate", "textDragOptions":
            if #available(iOS 11.0, *) {
                fallthrough
            }
            // Does nothing on iOS 10
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

let dataDetectorTypesType: RuntimeType = {
    var types = [
        "phoneNumber": .phoneNumber,
        "link": .link,
        "address": .address,
        "calendarEvent": .calendarEvent,
        "shipmentTrackingNumber": [],
        "flightNumber": [],
        "lookupSuggestion": [],
        "all": .all,
    ] as [String: UIDataDetectorTypes]
    #if swift(>=3.2)
        if #available(iOS 11.0, *) {
            types["shipmentTrackingNumber"] = .shipmentTrackingNumber
            types["flightNumber"] = .flightNumber
            types["lookupSuggestion"] = .lookupSuggestion
        }
    #endif
    return RuntimeType(types)
}()

extension UITextView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["textAlignment"] = textAlignmentType
        types["lineBreakMode"] = lineBreakModeType
        types["dataDetectorTypes"] = dataDetectorTypesType
        for (name, type) in textInputTraits {
            types[name] = type
        }
        for (name, type) in dragAndDropOptions {
            types[name] = type
        }

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "becomesEditableWithGestures",
                "contentOffsetForSameViewDrops",
                "continuousSpellCheckingEnabled",
                "forceDisableDictation",
                "forceEnableDictation",
                "marginTop",
                "shouldAutoscrollAboveBottom",
                "shouldPresentSheetsInAWindowLayeredAboveTheKeyboard",
                "tiledViewsDrawAsynchronously",
                "usesTiledViews",
            ] {
                types[name] = nil
                let name = "\(name)."
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif
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
        case "textDragDelegate", "textDropDelegate", "textDragOptions":
            if #available(iOS 11.0, *) {
                fallthrough
            }
            // Does nothing on iOS 10
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

let barStyleType = RuntimeType([
    "default": .default,
    "black": .black,
] as [String: UIBarStyle])

let barPositionType = RuntimeType([
    "any": .any,
    "bottom": .bottom,
    "top": .top,
    "topAttached": .topAttached,
] as [String: UIBarPosition])

extension UISearchBar {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["barPosition"] = barPositionType
        types["barStyle"] = barStyleType
        types["scopeButtonTitles"] = RuntimeType(Array<String>.self)
        types["searchBarStyle"] = RuntimeType([
            "default": .default,
            "prominent": .prominent,
            "minimal": .minimal,
        ] as [String: UISearchBarStyle])
        for (name, type) in textInputTraits {
            types[name] = type
        }

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "centerPlaceholder",
                "combinesLandscapeBars",
                "contentInset",
                "drawsBackground",
                "drawsBackgroundInPalette",
                "pretendsIsInBar",
                "searchFieldLeftViewMode",
                "searchTextPositionAdjustment",
                "usesEmbeddedAppearance",
            ] {
                types[name] = nil
                let name = "\(name)."
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif
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
        // TODO: find a good naming scheme for left/right state variants
        types["backgroundImage"] = RuntimeType(UIImage.self)
        types["titleColor"] = RuntimeType(UIColor.self)
        types["titleFont"] = RuntimeType(UIFont.self)
        for state in controlStates.keys {
            types["\(state)BackgroundImage"] = RuntimeType(UIImage.self)
            types["\(state)TitleColor"] = RuntimeType(UIColor.self)
            types["\(state)TitleFont"] = RuntimeType(UIFont.self)
        }
        types["dividerImage"] = RuntimeType(UIImage.self)
        types["contentPositionAdjustment"] = RuntimeType(UIOffset.self)
        types["contentPositionAdjustment.horizontal"] = RuntimeType(CGFloat.self)
        types["contentPositionAdjustment.vertical"] = RuntimeType(CGFloat.self)
        for segment in controlSegments.keys {
            types["\(segment)ContentPositionAdjustment"] = RuntimeType(UIOffset.self)
            types["\(segment)ContentPositionAdjustment.horizontal"] = RuntimeType(CGFloat.self)
            types["\(segment)ContentPositionAdjustment.vertical"] = RuntimeType(CGFloat.self)
        }

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "aloneContentPositionAdjustment",
                "alwaysNotifiesDelegateOfSegmentClicks",
                "anyContentPositionAdjustment",
                "axLongPressGestureRecognizer",
                "barStyle",
                "controlSize",
                "removedSegment",
                "segmentControlStyle",
                "segmentedControlStyle",
                "selectedSegment",
                "transparentBackground",
            ] {
                types[name] = nil
                let name = "\(name)."
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif
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

extension UIStepper {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        // TODO: find a good naming scheme for left/right state variants
        types["backgroundImage"] = RuntimeType(UIImage.self)
        types["incrementImage"] = RuntimeType(UIColor.self)
        types["decrementImage"] = RuntimeType(UIFont.self)
        for state in controlStates.keys {
            types["\(state)BackgroundImage"] = RuntimeType(UIImage.self)
            types["\(state)IncrementImage"] = RuntimeType(UIImage.self)
            types["\(state)DecrementImage"] = RuntimeType(UIImage.self)
        }
        types["dividerImage"] = RuntimeType(UIImage.self)
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

private let activityIndicatorStyle = RuntimeType([
    "whiteLarge": .whiteLarge,
    "white": .white,
    "gray": .gray,
] as [String: UIActivityIndicatorViewStyle])

extension UIActivityIndicatorView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["isAnimating"] = RuntimeType(Bool.self)
        types["activityIndicatorViewStyle"] = activityIndicatorStyle

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "animationDuration",
                "clockWise",
                "hasShadow",
                "innerRadius",
                "isHighlighted",
                "shadowColor",
                "shadowOffset",
                "spinning",
                "spinningDuration",
                "spokeCount",
                "spokeFrameRatio",
                "style",
                "useArtwork",
                "useOutlineShadow",
                "width",
            ] {
                types[name] = nil
                let name = "\(name)."
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "isAnimating":
            switch (value as! Bool, isAnimating) {
            case (true, false):
                startAnimating()
            case (false, true):
                stopAnimating()
            case (true, true), (false, false):
                break
            }
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override class var defaultExpressions: [String: String] {
        return ["isAnimating": "true"]
    }
}

extension UISwitch {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes

        #if arch(i386) || arch(x86_64)
            // Private
            types["visualElement"] = nil
        #endif
        return types
    }

    open override func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "isOn":
            setOn(value as! Bool, animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }
}

extension UISlider {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["thumbImage"] = RuntimeType(UIImage.self)
        types["minimumTrackImage"] = RuntimeType(UIImage.self)
        types["maximumTrackImage"] = RuntimeType(UIImage.self)
        for state in controlStates.keys {
            types["\(state)ThumbImage"] = RuntimeType(UIImage.self)
            types["\(state)MinimumTrackImage"] = RuntimeType(UIImage.self)
            types["\(state)MaximumTrackImage"] = RuntimeType(UIImage.self)
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "thumbImage": setThumbImage(value as? UIImage, for: .normal)
        case "minimumTrackImage": setMinimumTrackImage(value as? UIImage, for: .normal)
        case "maximumTrackImage": setMaximumTrackImage(value as? UIImage, for: .normal)
        default:
            if let (prefix, state) = controlStates.first(where: { name.hasPrefix($0.key) }) {
                switch name[prefix.endIndex ..< name.endIndex] {
                case "ThumbImage": setThumbImage(value as? UIImage, for: state)
                case "MinimumTrackImage": setMinimumTrackImage(value as? UIImage, for: state)
                case "MaximumTrackImage": setMaximumTrackImage(value as? UIImage, for: state)
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
        case "value":
            setValue(value as! Float, animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }
}

extension UIProgressView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["progressViewStyle"] = RuntimeType([
            "default": .default,
            "bar": .bar,
        ] as [String: UIProgressViewStyle])

        #if arch(i386) || arch(x86_64)
            // Private
            types["barStyle"] = nil
        #endif
        return types
    }

    open override func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "progress":
            setProgress(value as! Float, animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }
}

extension UIInputView {
    open override class func create(with node: LayoutNode) throws -> UIInputView {
        let inputViewStyle = try node.value(forExpression: "inputViewStyle") as? UIInputViewStyle ?? .default
        return self.init(frame: .zero, inputViewStyle: inputViewStyle)
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return [
            "inputViewStyle": RuntimeType([
                "default": .default,
                "keyboard": .keyboard,
            ] as [String: UIInputViewStyle]),
        ]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        #if arch(i386) || arch(x86_64)
            // Private and read-only properties
            for name in [
                "contentRatio",
                "leftContentViewSize",
                "rightContentViewSize",
            ] + [
                "inputViewStyle",
            ] {
                types[name] = nil
                let name = "\(name)."
                for key in types.keys where key.hasPrefix(name) {
                    types[key] = nil
                }
            }
        #endif
        return types
    }
}

extension UIDatePicker {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["datePickerMode"] = RuntimeType([
            "time": .time,
            "date": .date,
            "dateAndTime": .dateAndTime,
            "countDownTimer": .countDownTimer,
        ] as [String: UIDatePickerMode])

        #if arch(i386) || arch(x86_64)
            // Private properties
            for name in [
                "highlightsToday",
                "timeInterval",
                "staggerTimeIntervals",
            ] {
                types[name] = nil
            }
        #endif
        return types
    }

    open override func setAnimatedValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "date":
            setDate(value as! Date, animated: true)
        default:
            try super.setAnimatedValue(value, forExpression: name)
        }
    }
}

extension UIRefreshControl {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["isRefreshing"] = RuntimeType(Bool.self)

        #if arch(i386) || arch(x86_64)
            // Private property
            types["refreshControlState"] = nil
        #endif
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "isRefreshing":
            switch (value as! Bool, isRefreshing) {
            case (true, false):
                beginRefreshing()
            case (false, true):
                endRefreshing()
            case (true, true), (false, false):
                break
            }
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

extension UIPickerView {
}

private var baseURLKey = 1

extension UIWebView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["baseURL"] = RuntimeType(URL.self)
        types["htmlString"] = RuntimeType(String.self)
        types["request"] = RuntimeType(URLRequest.self)
        types["paginationMode"] = RuntimeType([
            "unpaginated": .unpaginated,
            "leftToRight": .leftToRight,
            "topToBottom": .topToBottom,
            "bottomToTop": .bottomToTop,
            "rightToLeft": .rightToLeft,
        ] as [String: UIWebPaginationMode])
        types["paginationBreakingMode"] = RuntimeType([
            "page": .page,
            "column": .column,
        ] as [String: UIWebPaginationBreakingMode])
        for (key, type) in UIScrollView.expressionTypes {
            types["scrollView.\(key)"] = type
        }
        // TODO: support loading data
        // TODO: support inline html

        #if arch(i386) || arch(x86_64)
            // Private
            types["detectsPhoneNumbers"] = nil
        #endif
        return types
    }

    @nonobjc private var baseURL: URL? {
        get { return objc_getAssociatedObject(self, &baseURLKey) as? URL }
        set {
            let url = baseURL.flatMap { $0.absoluteString.isEmpty ? nil : $0 }
            objc_setAssociatedObject(self, &baseURLKey, url, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "baseURL":
            baseURL = value as? URL
        case "htmlString":
            loadHTMLString(value as! String, baseURL: baseURL)
        case "request":
            loadRequest(value as! URLRequest)
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

private var readAccessURLKey = 1

extension WKWebView {
    open override class func create(with node: LayoutNode) throws -> WKWebView {
        if let configuration = try node.value(forExpression: "configuration") as? WKWebViewConfiguration {
            return self.init(frame: .zero, configuration: configuration)
        }
        return self.init(frame: .zero)
    }

    open override class var parameterTypes: [String: RuntimeType] {
        return ["configuration": RuntimeType(WKWebViewConfiguration.self)]
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["baseURL"] = RuntimeType(URL.self)
        types["fileURL"] = RuntimeType(URL.self)
        types["readAccessURL"] = RuntimeType(URL.self)
        types["htmlString"] = RuntimeType(String.self)
        types["request"] = RuntimeType(URLRequest.self)
        types["uiDelegate"] = RuntimeType(WKUIDelegate.self)
        types["UIDelegate"] = nil // TODO: find a way to automate this renaming
        for (key, type) in UIScrollView.expressionTypes {
            types["scrollView.\(key)"] = type
        }
        for (key, type) in WKWebViewConfiguration.allPropertyTypes() {
            types["configuration.\(key)"] = type
        }
        if #available(iOS 10, *) {
            types["configuration.mediaTypesRequiringUserActionForPlayback"] = RuntimeType([
                "audio": .audio,
                "video": .video,
                "all": .all,
            ] as [String: WKAudiovisualMediaTypes])
            types["configuration.dataDetectorTypes"] = RuntimeType([
                "phoneNumber": .phoneNumber,
                "link": .link,
                "address": .address,
                "calendarEvent": .calendarEvent,
                "trackingNumber": .trackingNumber,
                "flightNumber": .flightNumber,
                "lookupSuggestion": .lookupSuggestion,
                "all": .all,
            ] as [String: WKDataDetectorTypes])
        } else {
            types["configuration.mediaTypesRequiringUserActionForPlayback"] = RuntimeType([
                "audio": IntOptionSet(rawValue: 1),
                "video": IntOptionSet(rawValue: 2),
                "all": IntOptionSet(rawValue: 3),
            ] as [String: IntOptionSet])
            types["configuration.dataDetectorTypes"] = RuntimeType([
                "phoneNumber": IntOptionSet(rawValue: 1),
                "link": IntOptionSet(rawValue: 2),
                "address": IntOptionSet(rawValue: 4),
                "calendarEvent": IntOptionSet(rawValue: 8),
                "trackingNumber": IntOptionSet(rawValue: 16),
                "flightNumber": IntOptionSet(rawValue: 32),
                "lookupSuggestion": IntOptionSet(rawValue: 64),
                "all": IntOptionSet(rawValue: 127),
            ] as [String: IntOptionSet])
        }
        types["configuration.selectionGranularity"] = RuntimeType([
            "dynamic": .dynamic,
            "character": .character,
        ] as [String: WKSelectionGranularity])
        // TODO: support loading data
        // TODO: support inline html
        // TODO: support binding uiDelegate, navigationDelegate
        // TODO: support configuration url scheme handlers
        return types
    }

    @nonobjc private var readAccessURL: URL? {
        get { return objc_getAssociatedObject(self, &readAccessURLKey) as? URL }
        set {
            let url = readAccessURL.flatMap { $0.absoluteString.isEmpty ? nil : $0 }
            objc_setAssociatedObject(self, &readAccessURLKey, url, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    @nonobjc private var baseURL: URL? {
        get { return objc_getAssociatedObject(self, &baseURLKey) as? URL }
        set {
            let url = baseURL.flatMap { $0.absoluteString.isEmpty ? nil : $0 }
            objc_setAssociatedObject(self, &baseURLKey, url, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "baseURL":
            baseURL = value as? URL
        case "htmlString":
            loadHTMLString(value as! String, baseURL: baseURL)
        case "readAccessURL":
            readAccessURL = value as? URL
        case "fileURL":
            let fileURL = value as! URL
            if !fileURL.absoluteString.isEmpty, !fileURL.isFileURL {
                throw LayoutError("fileURL must refer to a local file")
            }
            loadFileURL(fileURL, allowingReadAccessTo: readAccessURL ?? fileURL)
        case "request":
            let request = value as! URLRequest
            if let url = request.url, url.isFileURL {
                loadFileURL(url, allowingReadAccessTo: readAccessURL ?? url)
            } else {
                load(request)
            }
        case "customUserAgent":
            let userAgent = value as! String
            customUserAgent = userAgent.isEmpty ? nil : userAgent
        case "uiDelegate":
            uiDelegate = value as? WKUIDelegate
        case "configuration.dataDetectorTypes",
             "configuration.mediaTypesRequiringUserActionForPlayback",
             "configuration.ignoresViewportScaleLimits":
            if #available(iOS 10, *) {
                fallthrough
            }
            // Does nothing on iOS 10
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}
