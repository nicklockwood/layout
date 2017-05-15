//
//  UIView+Layout.swift
//  Layout
//
//  Created by Nick Lockwood on 26/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

extension UIView {

    /// The view controller that owns the view - used to access layout guides
    var viewController: UIViewController? {
        var controller: UIViewController? = nil
        var responder: UIResponder? = self.next
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
    open class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        // TODO: support more properties
        types["backgroundColor"] = RuntimeType(UIColor.self)
        types["isHidden"] = RuntimeType(Bool.self)
        types["clipsToBounds"] = RuntimeType(Bool.self)
        types["alpha"] = RuntimeType(CGFloat.self)
        types["tintColor"] = RuntimeType(UIColor.self)
        types["contentMode"] = RuntimeType([
            "center": UIViewContentMode.center.rawValue,
            "scaleAspectFit": UIViewContentMode.scaleAspectFit.rawValue,
            "scaleAspectFill": UIViewContentMode.scaleAspectFill.rawValue,
        ])
        // TODO: better approach to layer properties?
        for (name, type) in (layerClass as! NSObject.Type).allPropertyTypes() {
            types["layer.\(name)"] = type
        }
        types["layer.borderColor"] = RuntimeType(CGColor.self)
        return types
    }

    // Set expression value
    open func setValue(_ value: Any, forExpression name: String) throws {
        try _setValue(value, forKeyPath: name)
    }

    /// Get symbol value
    open func value(forSymbol name: String) -> Any? {
        return _value(forKeyPath: name)
    }

    /// Called immediately after a child node is added
    open func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = self.viewController {
            for controller in node.viewControllers {
                viewController.addChildViewController(controller)
            }
        }
        insertSubview(node.view, at: index)
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

extension UIScrollView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["contentInset.top"] = RuntimeType(CGFloat.self)
        types["contentInset.bottom"] = RuntimeType(CGFloat.self)
        types["contentInset.left"] = RuntimeType(CGFloat.self)
        types["contentInset.right"] = RuntimeType(CGFloat.self)
        types["scrollIndicatorInsets.top"] = RuntimeType(CGFloat.self)
        types["scrollIndicatorInsets.bottom"] = RuntimeType(CGFloat.self)
        types["scrollIndicatorInsets.left"] = RuntimeType(CGFloat.self)
        types["scrollIndicatorInsets.right"] = RuntimeType(CGFloat.self)
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "contentInset.top":
            contentInset.top = value as! CGFloat
        case "contentInset.bottom":
            contentInset.bottom = value as! CGFloat
        case "contentInset.left":
            contentInset.left = value as! CGFloat
        case "contentInset.right":
            contentInset.right = value as! CGFloat
        case "scrollIndicatorInsets.top":
            scrollIndicatorInsets.top = value as! CGFloat
        case "scrollIndicatorInsets.bottom":
            scrollIndicatorInsets.bottom = value as! CGFloat
        case "scrollIndicatorInsets.left":
            scrollIndicatorInsets.left = value as! CGFloat
        case "scrollIndicatorInsets.right":
            scrollIndicatorInsets.right = value as! CGFloat
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override func didUpdateLayout(for node: LayoutNode) {
        // Update contentSize
        contentSize = node.contentSize
        // Prevents contentOffset glitch when rotating from portrait to landscape
        if isPagingEnabled {
            contentOffset = CGPoint(
                x: round(contentOffset.x / frame.size.width) * frame.size.width - contentInset.left,
                y: round(contentOffset.y / frame.size.height) * frame.size.height - contentInset.top
            )
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

private var layoutActionsKey: UInt8 = 0
extension UIControl {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for name in controlEvents.keys {
            types[name] = RuntimeType(String.self)
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        if let action = value as? String, let event = controlEvents[name] {
            var actions = objc_getAssociatedObject(self, &layoutActionsKey) as? [String: String] ?? [String: String]()
            if let oldAction = actions[name] {
                if oldAction == action {
                    return
                }
                removeTarget(nil, action: Selector(action), for: event)
            }
            addTarget(nil, action: Selector(action), for: event)
            actions[name] = action
            objc_setAssociatedObject(self, &layoutActionsKey, actions, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }
        try super.setValue(value, forExpression: name)
    }
}

extension UIButton {
    dynamic var title: String {
        set { setTitle(newValue, for: .normal) }
        get { return title(for: .normal) ?? "" }
    }
    dynamic var highlightedTitle: String {
        set { setTitle(newValue, for: .highlighted) }
        get { return title(for: .highlighted) ?? "" }
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["type"] = RuntimeType([
            "custom": UIButtonType.custom.rawValue,
            "system": UIButtonType.custom.rawValue,
            "detailDisclosure": UIButtonType.custom.rawValue,
            "infoLight": UIButtonType.infoLight.rawValue,
            "infoDark": UIButtonType.infoLight.rawValue,
            "contactAdd": UIButtonType.infoLight.rawValue,
        ])
        types["buttonType"] = types["type"]
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "type", "buttonType":
            setValue(value, forKey: "buttonType")
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

private let textInputTraits: [String: RuntimeType] = {
    var keyboardTypes = [
        "default": UIKeyboardType.default.rawValue,
        "asciiCapable": UIKeyboardType.asciiCapable.rawValue,
        "numbersAndPunctuation": UIKeyboardType.numbersAndPunctuation.rawValue,
        "URL": UIKeyboardType.URL.rawValue,
        "url": UIKeyboardType.URL.rawValue,
        "numberPad": UIKeyboardType.numberPad.rawValue,
        "phonePad": UIKeyboardType.phonePad.rawValue,
        "namePhonePad": UIKeyboardType.namePhonePad.rawValue,
        "emailAddress": UIKeyboardType.emailAddress.rawValue,
        "decimalPad": UIKeyboardType.decimalPad.rawValue,
        "twitter": UIKeyboardType.twitter.rawValue,
        "webSearch": UIKeyboardType.webSearch.rawValue,
    ]
    if #available(iOS 10.0, *) {
        keyboardTypes["asciiCapableNumberPad"] = UIKeyboardType.asciiCapableNumberPad.rawValue
    }
    return [
        "autocapitalizationType": RuntimeType([
            "none": UITextAutocapitalizationType.none.rawValue,
            "words": UITextAutocapitalizationType.words.rawValue,
            "sentences": UITextAutocapitalizationType.sentences.rawValue,
            "allCharacters": UITextAutocapitalizationType.allCharacters.rawValue,
        ]),
        "autocorrectionType": RuntimeType([
            "default": UITextAutocorrectionType.default.rawValue,
            "no": UITextAutocorrectionType.no.rawValue,
            "yes": UITextAutocorrectionType.yes.rawValue,
        ]),
        "spellCheckingType": RuntimeType([
            "default": UITextSpellCheckingType.default.rawValue,
            "no": UITextSpellCheckingType.no.rawValue,
            "yes": UITextSpellCheckingType.yes.rawValue,
        ]),
        "keyboardType": RuntimeType(keyboardTypes),
        "keyboardAppearance": RuntimeType([
            "default": UIKeyboardAppearance.default.rawValue,
            "dark": UIKeyboardAppearance.dark.rawValue,
            "light": UIKeyboardAppearance.light.rawValue,
        ]),
        "returnKeyType": RuntimeType([
            "default": UIReturnKeyType.default.rawValue,
            "go": UIReturnKeyType.go.rawValue,
            "google": UIReturnKeyType.google.rawValue,
            "join": UIReturnKeyType.join.rawValue,
            "next": UIReturnKeyType.next.rawValue,
            "route": UIReturnKeyType.route.rawValue,
            "search": UIReturnKeyType.search.rawValue,
            "send": UIReturnKeyType.send.rawValue,
            "yahoo": UIReturnKeyType.yahoo.rawValue,
            "done": UIReturnKeyType.done.rawValue,
            "emergencyCall": UIReturnKeyType.emergencyCall.rawValue,
            "continue": UIReturnKeyType.continue.rawValue,
        ]),
        "enablesReturnKeyAutomatically": RuntimeType(Bool.self),
        "isSecureTextEntry": RuntimeType(Bool.self),
    ]
}()

private let textTraits = [
    "textAlignment": RuntimeType([
        "left": NSTextAlignment.left.rawValue,
        "right": NSTextAlignment.right.rawValue,
        "center": NSTextAlignment.center.rawValue,
    ])
]

extension UILabel {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textTraits {
            types[name] = type
        }
        types["baselineAdjustment"] = RuntimeType([
            "alignBaselines": UIBaselineAdjustment.alignBaselines.rawValue,
            "alignCenters": UIBaselineAdjustment.alignCenters.rawValue,
            "none": UIBaselineAdjustment.none.rawValue,
        ])
        return types
    }
}

private let textFieldViewMode = RuntimeType([
    "never": UITextFieldViewMode.never.rawValue,
    "whileEditing": UITextFieldViewMode.whileEditing.rawValue,
    "unlessEditing": UITextFieldViewMode.unlessEditing.rawValue,
    "always": UITextFieldViewMode.always.rawValue,
])

extension UITextField {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textInputTraits {
            types[name] = type
        }
        for (name, type) in textTraits {
            types[name] = type
        }
        types["borderStyle"] = RuntimeType([
            "none": UITextBorderStyle.none.rawValue,
            "line": UITextBorderStyle.line.rawValue,
            "bezel": UITextBorderStyle.bezel.rawValue,
            "roundedRect": UITextBorderStyle.roundedRect.rawValue,
        ])
        types["clearButtonMode"] = textFieldViewMode
        types["leftViewMode"] = textFieldViewMode
        types["rightViewMode"] = textFieldViewMode
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        // NOTE: for some reason, these properties don't support KVC
        switch name {
        case "autocapitalizationType":
            autocapitalizationType = UITextAutocapitalizationType(rawValue: value as! Int)!
        case "autocorrectionType":
            autocorrectionType = UITextAutocorrectionType(rawValue: value as! Int)!
        case "keyboardType":
            keyboardType = UIKeyboardType(rawValue: value as! Int)!
        case "keyboardAppearance":
            keyboardAppearance = UIKeyboardAppearance(rawValue: value as! Int)!
        case "returnKeyType":
            returnKeyType = UIReturnKeyType(rawValue: value as! Int)!
        case "enablesReturnKeyAutomatically":
            enablesReturnKeyAutomatically = value as! Bool
        case "isSecureTextEntry":
            isSecureTextEntry = value as! Bool
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
        // NOTE: for some reason, these properties don't support KVC
        switch name {
        case "autocapitalizationType":
            autocapitalizationType = UITextAutocapitalizationType(rawValue: value as! Int)!
        case "autocorrectionType":
            autocorrectionType = UITextAutocorrectionType(rawValue: value as! Int)!
        case "keyboardType":
            keyboardType = UIKeyboardType(rawValue: value as! Int)!
        case "keyboardAppearance":
            keyboardAppearance = UIKeyboardAppearance(rawValue: value as! Int)!
        case "returnKeyType":
            returnKeyType = UIReturnKeyType(rawValue: value as! Int)!
        case "enablesReturnKeyAutomatically":
            enablesReturnKeyAutomatically = value as! Bool
        case "isSecureTextEntry":
            isSecureTextEntry = value as! Bool
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}
