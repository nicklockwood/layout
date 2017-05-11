//
//  LayoutNode.swift
//  UIDesigner
//
//  Created by Nick Lockwood on 21/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

public class LayoutNode: NSObject {
    public let view: UIView
    public let viewController: UIViewController?
    public private(set) var outlet: String?
    public private(set) var expressions: [String: String]
    public internal(set) var constants: [String: Any]

    public var viewControllers: [UIViewController] {
        guard let viewController = viewController else {
            return children.flatMap { $0.viewControllers }
        }
        return [viewController]
    }

    public init(
        view: UIView? = nil,
        viewController: UIViewController? = nil,
        outlet: String? = nil,
        state: Any = Void(),
        constants: [String: Any] = [:],
        expressions: [String: String] = [:],
        children: [LayoutNode] = []
    ) {
        assert(Thread.isMainThread)

        let view = view ?? viewController?.view ?? UIView()
        viewController?.view = view
        view.autoresizingMask = []

        self.view = view
        self.viewController = viewController
        self.outlet = outlet
        self.state = state
        self.constants = constants
        self.expressions = expressions
        self.children = children

        super.init()

        overrideExpressions()

        #if arch(i386) || arch(x86_64)

            // Validate expressions
            for name in expressions.keys {
                if expression(for: name) == nil {
                    logError(SymbolError("Unknown expression name `\(name)`", for: name))
                }
            }
            for error in redundantExpressionErrors() {
                logError(error)
            }

        #endif

        for (index, child) in children.enumerated() {
            child.parent = self
            if let viewController = view.viewController {
                viewController.didInsertChildNode(child, at: index)
            } else {
                view.didInsertChildNode(child, at: index)
            }
        }
        updateVariables()
    }

    // MARK: Validation

    public static func isValidExpressionName(_ name: String,
                                             for viewOrViewControllerClass: NSObject.Type) -> Bool {
        switch name {
        case "top", "left", "bottom", "right", "width", "height":
            return true
        case _ where viewOrViewControllerClass is UIView.Type:
            return viewOrViewControllerClass.allPropertyTypes()[name] != nil
        case _ where viewOrViewControllerClass is UIViewController.Type:
            return viewOrViewControllerClass.allPropertyTypes()[name] != nil ||
                UIView.allPropertyTypes()[name] != nil
        default:
            preconditionFailure("\(viewOrViewControllerClass) is not a UIView or UIViewController subclass")
        }
    }

    /// Perform pre-validation on the node and (optionally) its children
    public func validate(recursive: Bool = true) -> [LayoutError] {
        var errors = [LayoutError]()
        for name in expressions.keys {
            guard let expression = expression(for: name) else {
                errors.append(LayoutError(SymbolError("Unknown expression name `\(name)`", for: name), for: self))
                continue
            }
            do {
                _ = try expression.evaluate()
            } catch {
                errors.append(LayoutError(error, for: self))
            }
        }
        errors += redundantExpressionErrors()
        if recursive {
            for child in children {
                errors += child.validate()
            }
        }
        return errors
    }

    private func redundantExpressionErrors() -> [LayoutError] {
        var errors = [LayoutError]()
        if !(expressions["bottom"] ?? "").isEmpty,
            !value(forSymbol: "height", dependsOn: "bottom"),
            !value(forSymbol: "top", dependsOn: "bottom") {
            errors.append(LayoutError(SymbolError("Expression for `bottom` is redundant",
                                                  for: "bottom"), for: self))
        }
        if !(expressions["right"] ?? "").isEmpty,
            !value(forSymbol: "width", dependsOn: "right"),
            !value(forSymbol: "left", dependsOn: "right") {
            errors.append(LayoutError(SymbolError("Expression for `right` is redundant",
                                                  for: "right"), for: self))
        }
        return errors
    }

    private var _unhandledError: LayoutError?
    private func throwUnhandledError() throws {
        try _unhandledError.map {
            _unhandledError = nil
            throw $0
        }
    }

    private func logError(_ error: Error) {
        _unhandledError = LayoutError(error, for: self)
        #if arch(i386) || arch(x86_64)
            print("Error: \(_unhandledError!)")
        #endif
    }

    private func attempt<T>(_ closure: () throws -> T) -> T? {
        do {
            return try closure()
        } catch {
            logError(error)
            return nil
        }
    }

    // MARK: State

    public var state: Any {
        didSet {
            if let newState = state as? [String: Any] {
                // Merge
                if var oldState = oldValue as? [String: Any] {
                    for (key, value) in newState {
                        oldState[key] = value
                    }
                    state = oldState
                }
            } else {
                assert(type(of: oldValue) == Void.self || type(of: oldValue) == type(of: state),
                   "Cannot change type of state after initialization")
            }
            updateVariables()
        }
    }

    private var _variables = [String: Any]()
    private func updateVariables() {
        if let members = state as? [String: Any] {
            _variables = members
        } else {
            // TODO: flatten nested objects
            let mirror = Mirror(reflecting: state)
            for (name, value) in mirror.children {
                if let name = name {
                    _variables[name] = value
                }
            }
        }
        // TODO: work out which expressions are actually affected
        attempt(update)
    }

    // MARK: Hierarchy

    public private(set) var children: [LayoutNode]
    public private(set) weak var parent: LayoutNode? {
        didSet {
            _getters.removeAll()
            _cachedExpressions.removeAll()
            overrideExpressions()
        }
    }

    var previous: LayoutNode? {
        if let siblings = parent?.children, let index = siblings.index(where: { $0 === self }), index > 0 {
            return siblings[index - 1]
        }
        return nil
    }

    var next: LayoutNode? {
        if let siblings = parent?.children, let index = siblings.index(where: { $0 === self }),
            index < siblings.count - 1 {
            return siblings[index + 1]
        }
        return nil
    }

    public func addChild(_ child: LayoutNode) {
        insertChild(child, at: children.count)
    }

    public func insertChild(_ child: LayoutNode, at index: Int) {
        child.removeFromParent()
        children.insert(child, at: index)
        child.parent = self
        if let owner = _owner {
            try? child.bind(to: owner)
        }
        if let viewController = viewController {
            viewController.didInsertChildNode(child, at: index)
        } else {
            view.didInsertChildNode(child, at: index)
        }
        try? update()
    }

    public func replaceChild(at index: Int, with child: LayoutNode) {
        let oldChild = children[index]
        children[index] = child
        child.parent = self
        if let owner = _owner {
            try? child.bind(to: owner)
        }
        if let viewController = viewController {
            viewController.didInsertChildNode(child, at: index)
        } else {
            view.didInsertChildNode(child, at: index)
        }
        oldChild.removeFromParent()
    }

    public func removeFromParent() {
        if let index = parent?.children.index(where: { $0 === self }) {
            if let viewController = parent?.viewController {
                viewController.willRemoveChildNode(self, at: index)
            } else {
                parent?.view.willRemoveChildNode(self, at: index)
            }
            unbind()
            parent?.children.remove(at: index)
            try? parent?.update()
            parent = nil
            return
        }
        view.removeFromSuperview()
        for controller in viewControllers {
            controller.removeFromParentViewController()
        }
    }

    // Experimental - used for nested XML reference loading
    internal func update(with node: LayoutNode) throws {
        guard type(of: view) == type(of: node.view) else {
            throw LayoutError.message("Cannot replace \(type(of: view)) with \(type(of: node.view))")
        }
        guard (viewController == nil) == (node.viewController == nil) else {
            throw LayoutError.message("Cannot replace \(viewController.map { "\(type(of: $0))" } ?? "nil") with \(node.viewController.map { "\(type(of: $0))" } ?? "nil")")
        }
        guard viewController.map({ type(of: $0) == type(of: node.viewController!) }) != false else {
            throw LayoutError.message("Cannot replace \(type(of: viewController!)) with \(type(of: node.viewController!))")
        }

        for child in children {
            child.removeFromParent()
        }

        for (name, expression) in node.expressions {
            expressions[name] = expression
        }
        _getters.removeAll()
        _cachedExpressions.removeAll()
        overrideExpressions()

        if let outlet = node.outlet {
            self.outlet = outlet
            try _owner.map { try bind(to: $0) }
        }

        for child in node.children {
            addChild(child)
        }
        try update()
    }

    // MARK: expressions

    private func overrideExpressions() {
        // layout props
        if expressions["width"] == nil {
            if expressions["left"] != nil, expressions["right"] != nil {
                expressions["width"] = "right - left"
            } else if !view.constraints.isEmpty || view.intrinsicContentSize.width != UIViewNoIntrinsicMetric {
                expressions["width"] = "auto"
            } else {
                expressions["width"] = "100%"
            }
        }
        if expressions["left"] == nil {
            expressions["left"] = expressions["right"] != nil ? "right - width" : "0"
        }
        if expressions["height"] == nil {
            if expressions["top"] != nil, expressions["bottom"] != nil {
                expressions["height"] = "bottom - top"
            } else if !view.constraints.isEmpty || view.intrinsicContentSize.height != UIViewNoIntrinsicMetric {
                expressions["height"] = "auto"
            } else {
                expressions["height"] = "100%"
            }
        }
        if expressions["top"] == nil {
            expressions["top"] = expressions["bottom"] != nil ? "bottom - height" : "0"
        }

        // Override expressions
        if let parent = parent {
            if let viewController = parent.viewController {
                expressions = viewController.overrideExpressionsForChildNode(self)
            } else {
                expressions = parent.view.overrideExpressionsForChildNode(self)
            }
        }

        // Handle Autolayout
        if let widthConstraint = _widthConstraint {
            view.removeConstraint(widthConstraint)
            _widthConstraint = nil
        }
        if let heightConstraint = _heightConstraint {
            view.removeConstraint(heightConstraint)
            _heightConstraint = nil
        }
        if children.isEmpty, !view.constraints.isEmpty {
            if expressions["width"] != nil {
                _widthConstraint = view.widthAnchor.constraint(equalToConstant: 0)
                _widthConstraint?.isActive = true
            }
            if expressions["height"] != nil {
                _heightConstraint = view.heightAnchor.constraint(equalToConstant: 0)
                _heightConstraint?.isActive = true
            }
        }
    }

    private var _cachedExpressions = [String: LayoutExpression]()
    private func expression(for symbol: String) -> LayoutExpression? {
        if let expression = _cachedExpressions[symbol] {
            return expression
        }
        if let string = expressions[symbol] {
            var expression: LayoutExpression
            switch symbol {
            case "left", "right":
                expression = LayoutExpression(xExpression: string, for: self)
            case "top", "bottom":
                expression = LayoutExpression(yExpression: string, for: self)
            case "width":
                expression = LayoutExpression(widthExpression: string, for: self)
            case "height":
                expression = LayoutExpression(heightExpression: string, for: self)
            default:
                guard let type = viewControllerExpressionTypes[symbol] ?? viewExpressionTypes[symbol] else {
                    return nil // Not a valid expression
                }
                expression = LayoutExpression(expression: string, ofType: type, for: self)
            }
            // Optimize constant expressions
            func isConstant(_ expression: LayoutExpression) -> Bool {
                for name in expression.symbols {
                    if name == symbol {
                        // Circular reference, abort!
                        return false
                    }
                    if let expression = self.expression(for: name) {
                        if !isConstant(expression) {
                            return false
                        }
                    } else if self.value(forConstant: name) == nil {
                        return false
                    }
                }
                return true
            }
            if isConstant(expression), let value = try? expression.evaluate() {
                expression = LayoutExpression(evaluate: { value }, symbols: [])
                // TODO: refactor so that this can be done more cleanly
                guard let _ = try? setValue(value, forExpression: symbol) else {
                    // Something went wrong, so don't cache the expression
                    return expression
                }
            }
            _cachedExpressions[symbol] = expression
            return expression
        }
        return nil
    }

    // MARK: symbols

    private func value(forConstant name: String) -> Any? {
        return constants[name] ?? parent?.value(forConstant: name)
    }

    private func value(forVariableOrConstant name: String) -> Any? {
        return _variables[name] ?? constants[name] ?? parent?.value(forVariableOrConstant: name)
    }

    public lazy var viewExpressionTypes: [String: RuntimeType] = {
        return type(of: self.view).expressionTypes
    }()

    public lazy var viewControllerExpressionTypes: [String: RuntimeType] = {
        return self.viewController.map({ type(of: $0) })?.expressionTypes ?? [:]
    }()

    private class func isLayoutSymbol(_ name: String) -> Bool {
        switch name {
        case "left", "right", "width", "top", "bottom", "height":
            return true
        default:
            return false
        }
    }

    func value(forSymbol name: String, dependsOn symbol: String) -> Bool {
        if let expression = expression(for: name) {
            for name in expression.symbols where name == symbol || value(forSymbol: name, dependsOn: symbol) {
                return true
            }
        }
        return false
    }

    // Note: thrown error is always a SymbolError
    func doubleValue(forSymbol symbol: String) throws -> Double! {
        guard let anyValue = try value(forSymbol: symbol) else {
            return nil // Fall back to standard library
        }
        if let doubleValue = anyValue as? Double {
            return doubleValue
        }
        if let cgFloatValue = anyValue as? CGFloat {
            return Double(cgFloatValue)
        }
        if let numberValue = anyValue as? NSNumber {
            return Double(numberValue)
        }
        throw SymbolError("\(symbol) is not a number", for: symbol)
    }

    private var _evaluating = [String]()
    private var _getters = [String: () throws -> Any?]()

    // Return the best available VC for computing the layout guide
    private var _layoutGuideController: UIViewController? {
        let controller = view.viewController
        return controller?.tabBarController?.selectedViewController ??
            controller?.navigationController?.topViewController ?? controller
    }

    // Note: thrown error is always a SymbolError
    public func value(forSymbol symbol: String) throws -> Any! {
        if let getter = _getters[symbol] {
            return try SymbolError.wrap(getter, for: symbol)
        }
        if let expression = expression(for: symbol) {
            let getter = { [unowned self] () throws -> Any in
                if self._evaluating.last == symbol, let value = self.value(forVariableOrConstant: symbol) {
                    // In the situation that an expression directly references itself
                    // it may be that this is due to the expression name shadowing
                    // a constant or variable, so check for that first before throwing
                    return value
                }
                guard !self._evaluating.contains(symbol) else {
                    throw SymbolError("Circular reference", for: symbol)
                }
                self._evaluating.append(symbol)
                defer {
                    assert(self._evaluating.last == symbol)
                    self._evaluating.removeLast()
                }
                do {
                    return try expression.evaluate()
                } catch {
                    throw SymbolError(error, for: symbol)
                }
            }
            _getters[symbol] = getter
            return try SymbolError.wrap(getter, for: symbol)
        }
        let getter: () throws -> Any?
        switch symbol {
        case "left":
            getter = (parent == nil) ? { [unowned self] in self.view.frame.minX } : { 0 }
        case "width":
            getter = { [unowned self] in self.view.frame.width }
        case "right":
            getter = { [unowned self] in self.view.frame.maxX }
        case "top":
            getter = (parent == nil) ? { [unowned self] in self.view.frame.minY } : { 0 }
        case "height":
            getter = { [unowned self] in self.view.frame.height }
        case "bottom":
            getter = { [unowned self] in self.view.frame.maxY }
        case "topLayoutGuide.length":
            getter = { [unowned self] in self._layoutGuideController?.topLayoutGuide.length ?? 0 }
        case "bottomLayoutGuide.length":
            getter = { [unowned self] in self._layoutGuideController?.bottomLayoutGuide.length ?? 0 }
        default:
            var parts = symbol.components(separatedBy: ".")
            let tail = parts.dropFirst().joined(separator: ".")
            switch parts[0] {
            case "parent":
                if parent != nil {
                    getter = { [unowned self] in try self.parent!.value(forSymbol: tail) }
                } else {
                    getter = { [unowned self] in
                        switch tail {
                        case "width":
                            return self.view.superview?.bounds.width ?? 0
                        case "height":
                            return self.view.superview?.bounds.height ?? 0
                        default:
                            throw SymbolError("Undefined symbol `\(tail)`", for: symbol)
                        }
                    }
                }
            case "previous" where LayoutNode.isLayoutSymbol(tail):
                getter = { [unowned self] in
                    var previous = self.previous
                    while previous?.isHidden == true {
                        previous = previous?.previous
                    }
                    return try previous?.value(forSymbol: tail) ?? 0
                }
            case "previous":
                getter = { [unowned self] in try self.previous?.value(forSymbol: tail) ?? 0 }
            case "next" where LayoutNode.isLayoutSymbol(tail):
                getter = { [unowned self] in
                    var next = self.next
                    while next?.isHidden == true {
                        next = next?.next
                    }
                    return try next?.value(forSymbol: tail) ?? 0
                }
            case "next":
                getter = { [unowned self] in try self.next?.value(forSymbol: tail) ?? 0 }
            default:
                getter = { [unowned self] in
                    // Try constants first, then view/controller symbols, then fall back to standard library
                    self.value(forVariableOrConstant: symbol) ??
                        self.viewController?.value(forSymbol: symbol) ??
                        self.view.value(forSymbol: symbol)
                }
            }
        }
        _getters[symbol] = getter
        return try SymbolError.wrap(getter, for: symbol)
    }

    // Note: thrown error is always a SymbolError
    private func updateExpressionValues() throws {
        for name in expressions.keys {
            if let expression = _cachedExpressions[name], expression.symbols.isEmpty {
                // Crude optimization to avoid setting constant properties multiple times
                continue
            }
            if let anyValue = try value(forSymbol: name) {
                try setValue(anyValue, forExpression: name)
            }
        }
    }

    // Note: thrown error is always a SymbolError
    private func setValue(_ value: Any, forExpression name: String) throws {
        if let type = viewControllerExpressionTypes[name] {
            guard let value = type.cast(value) else {
                throw SymbolError("Type mismatch", for: name)
            }
            try viewController?.setValue(value, forExpression: name)
        }
        if let type = viewExpressionTypes[name] {
            guard let value = type.cast(value) else {
                throw SymbolError("Type mismatch", for: name)
            }
            try view.setValue(value, forExpression: name)
        }
    }

    // MARK: layout

    public var isHidden: Bool {
        return view.isHidden
    }

    public var frame: CGRect {
        return attempt({
            return CGRect(
                x: try CGFloat(doubleValue(forSymbol: "left")),
                y: try CGFloat(doubleValue(forSymbol: "top")),
                width: try CGFloat(doubleValue(forSymbol: "width")),
                height: try CGFloat(doubleValue(forSymbol: "height"))
            )
        }) ?? .zero
    }

    public var contentSize: CGSize {
        return attempt({
            if _widthConstraint != nil || _heightConstraint != nil {
                let frame = view.frame
                view.translatesAutoresizingMaskIntoConstraints = false
                if let widthConstraint = _widthConstraint, !_evaluating.contains("width") {
                    widthConstraint.constant = try CGFloat(doubleValue(forSymbol: "width"))
                } else {
                    _widthConstraint?.isActive = false
                }
                if let heightConstraint = _heightConstraint, !_evaluating.contains("height") {
                    heightConstraint.constant = try CGFloat(doubleValue(forSymbol: "height"))
                } else {
                    _heightConstraint?.isActive = false
                }
                view.setNeedsLayout()
                view.layoutIfNeeded()
                view.translatesAutoresizingMaskIntoConstraints = true
                _widthConstraint?.isActive = true
                _heightConstraint?.isActive = true
                let size = view.frame.size
                view.frame = frame
                return size
            }
            if view.intrinsicContentSize.width != UIViewNoIntrinsicMetric ||
                view.intrinsicContentSize.height != UIViewNoIntrinsicMetric {
                var targetSize = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                        height: CGFloat.greatestFiniteMagnitude)
                if !_evaluating.contains("width") {
                    targetSize.width = try CGFloat(doubleValue(forSymbol: "width"))
                }
                if !_evaluating.contains("height") {
                    targetSize.height = try CGFloat(doubleValue(forSymbol: "height"))
                }
                return view.systemLayoutSizeFitting(targetSize)
            }
            var size = CGSize.zero
            for child in children where !child.isHidden {
                let frame = child.frame
                size.width = max(size.width, frame.maxX)
                size.height = max(size.height, frame.maxY)
            }
            if size == .zero {
                return view.superview?.bounds.size ?? .zero
            }
            return size
        }) ?? .zero
    }

    private var _widthConstraint: NSLayoutConstraint?
    private var _heightConstraint: NSLayoutConstraint?

    // Note: thrown error is always a LayoutError
    private var _suppressUpdates = false
    public func update() throws {
        guard parent != nil || view.superview != nil else { return }
        guard _suppressUpdates == false else { return }
        defer { _suppressUpdates = false }
        _suppressUpdates = true
        try LayoutError.wrap(updateExpressionValues, for: self)
        for child in children {
            try child.update()
        }
        view.frame = frame
        view.didUpdateLayout(for: self)
        view.viewController?.didUpdateLayout(for: self)
        try throwUnhandledError()
    }

    // MARK: binding

    // Note: thrown error is always a LayoutError
    public func mount(in viewController: UIViewController) throws {
        try bind(to: viewController)
        for controller in viewControllers {
            viewController.addChildViewController(controller)
        }
        viewController.view.addSubview(view)
        if viewController.view.frame != .zero {
            try update()
        }
    }

    // Note: thrown error is always a LayoutError
    @nonobjc public func mount(in view: UIView) throws {
        guard parent == nil else {
            throw LayoutError.message("The `mount()` method should only be used on a root node.")
        }
        do {
            try bind(to: view)
        } catch let outerError {
            guard let viewController = view.viewController else {
                throw outerError
            }
            if (try? bind(to: viewController)) == nil {
                throw outerError
            }
        }
        if let viewController = view.viewController {
            for controller in viewControllers {
                viewController.addChildViewController(controller)
            }
        }
        view.addSubview(self.view)
        if view.frame != .zero {
            try update()
        }
    }

    /// Unmounts and unbinds the node
    public func unmount() {
        guard parent == nil else {
            // If not a root node, treat the same as `removeFromParent()`
            // TODO: should this be an error instead?
            removeFromParent()
            return
        }
        unbind()
        for controller in viewControllers {
            controller.removeFromParentViewController()
        }
        view.removeFromSuperview()
    }

    // Note: thrown error is always a LayoutError
    public func bind(to owner: NSObject) throws {
        try bind(to: owner, with: type(of: owner).allPropertyTypes())
    }

    // Note: thrown error is always a LayoutError
    private weak var _owner: NSObject?
    private func bind(to owner: NSObject, with outlets: [String: RuntimeType]) throws {
        _owner = owner
        if let outlet = outlet {
            guard let type = outlets[outlet] else {
                throw LayoutError.message("`\(type(of: owner))` does not have an outlet named `\(outlet)`")
            }
            var didMatch = false
            var expectedType = "UIView or LayoutNode"
            if type.matches(LayoutNode.self) {
                if type.matches(self) {
                    owner.setValue(self, forKey: outlet)
                    didMatch = true
                } else {
                    expectedType = "\(type(of: self))"
                }
            } else if type.matches(UIView.self) {
                if type.matches(view) {
                    owner.setValue(view, forKey: outlet)
                    didMatch = true
                } else {
                    expectedType = "\(type(of: view))"
                }
            }
            if !didMatch {
                throw LayoutError.message("outlet `\(outlet)` of `\(type(of: owner))` is not a \(expectedType)")
            }
        }
        if let type = viewExpressionTypes["delegate"] {
            if type.matches(owner), view.value(forKey: "delegate") == nil {
                view.setValue(owner, forKey: "delegate")
            }
        }
        if let type = viewExpressionTypes["dataSource"] {
            if type.matches(owner), view.value(forKey: "dataSource") == nil {
                view.setValue(owner, forKey: "dataSource")
            }
        }
        for child in children {
            try child.bind(to: owner, with: outlets)
        }
        try throwUnhandledError()
    }

    private func unbind() {
        if let outlet = outlet, let owner = _owner,
            type(of: owner).allPropertyTypes()[outlet] != nil {
            owner.setValue(nil, forKey: outlet)
        }
        for child in children {
            child.unbind()
        }
        _owner = nil
    }
}
