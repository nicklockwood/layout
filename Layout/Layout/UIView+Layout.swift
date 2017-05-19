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
        ])
        // Explicitly disabled view properties
        types["frame"] = nil
        types["bounds"] = nil
        types["center"] = nil
        types["autoresizingMask"] = nil
        // TODO: better approach to layer properties?
        for (name, type) in (layerClass as! NSObject.Type).allPropertyTypes() {
            types["layer.\(name)"] = type
        }
        types["layer.borderColor"] = RuntimeType(CGColor.self)
        // Explicitly disabled layer properties
        types["layer.frame"] = nil
        types["layer.bounds"] = nil
        types["layer.position"] = nil
        types["layer.anchorPoint"] = nil
        return types
    }

    // Set expression value
    open func setValue(_ value: Any, forExpression name: String) throws {
        var value = value
        if let type = type(of: self).expressionTypes[name]?.type, case let .enum(_, _, adaptor) = type {
            value = adaptor(value) // TODO: something nicer than this
        }
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
        types["type"] = RuntimeType(UIButtonType.self, [
            "custom": .custom,
            "system": .system,
            "detailDisclosure": .detailDisclosure,
            "infoLight": .infoLight,
            "infoDark": .infoDark,
            "contactAdd": .contactAdd,
        ])
        types["buttonType"] = types["type"]
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "type", "buttonType":
            setValue((value as! UIButtonType).rawValue, forKey: "buttonType")
        default:
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
    }
    return [
        "autocapitalizationType": RuntimeType(UITextAutocapitalizationType.self, [
            "none": .none,
            "words": .words,
            "sentences": .sentences,
            "allCharacters": .allCharacters,
        ]),
        "autocorrectionType": RuntimeType(UITextAutocorrectionType.self, [
            "default": .default,
            "no": .no,
            "yes": .yes,
        ]),
        "spellCheckingType": RuntimeType(UITextSpellCheckingType.self, [
            "default": .default,
            "no": .no,
            "yes": .yes,
        ]),
        "keyboardType": RuntimeType(UIKeyboardType.self, keyboardTypes),
        "keyboardAppearance": RuntimeType(UIKeyboardAppearance.self, [
            "default": .default,
            "dark": .dark,
            "light": .light,
        ]),
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
        ]),
        "enablesReturnKeyAutomatically": RuntimeType(Bool.self),
        "isSecureTextEntry": RuntimeType(Bool.self),
    ]
}()

private let textTraits = [
    "textAlignment": RuntimeType(NSTextAlignment.self, [
        "left": .left,
        "right": .right,
        "center": .center,
    ])
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
        ])
        return types
    }
}

private let textFieldViewMode = RuntimeType(UITextFieldViewMode.self, [
    "never": .never,
    "whileEditing": .whileEditing,
    "unlessEditing": .unlessEditing,
    "always": .always,
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
        types["borderStyle"] = RuntimeType(UITextBorderStyle.self, [
            "none": .none,
            "line": .line,
            "bezel": .bezel,
            "roundedRect": .roundedRect,
        ])
        types["clearButtonMode"] = textFieldViewMode
        types["leftViewMode"] = textFieldViewMode
        types["rightViewMode"] = textFieldViewMode
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "autocapitalizationType":
            autocapitalizationType = value as! UITextAutocapitalizationType
        case "autocorrectionType":
            autocorrectionType = value as! UITextAutocorrectionType
        case "spellCheckingType":
            spellCheckingType = value as! UITextSpellCheckingType
        case "keyboardType":
            keyboardType = value as! UIKeyboardType
        case "keyboardAppearance":
            keyboardAppearance = value as! UIKeyboardAppearance
        case "returnKeyType":
            returnKeyType = value as! UIReturnKeyType
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
        switch name {
        case "autocapitalizationType":
            autocapitalizationType = value as! UITextAutocapitalizationType
        case "autocorrectionType":
            autocorrectionType = value as! UITextAutocorrectionType
        case "spellCheckingType":
            spellCheckingType = value as! UITextSpellCheckingType
        case "keyboardType":
            keyboardType = value as! UIKeyboardType
        case "keyboardAppearance":
            keyboardAppearance = value as! UIKeyboardAppearance
        case "returnKeyType":
            returnKeyType = value as! UIReturnKeyType
        case "enablesReturnKeyAutomatically":
            enablesReturnKeyAutomatically = value as! Bool
        case "isSecureTextEntry":
            isSecureTextEntry = value as! Bool
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}
