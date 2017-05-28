//
//  LayoutNode.swift
//  UIDesigner
//
//  Created by Nick Lockwood on 21/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

public protocol LayoutDelegate {
    func layoutNode(_ layoutNode: LayoutNode, didDetectError error: LayoutError)
}

public class LayoutNode: NSObject {
    public let view: UIView
    public let viewController: UIViewController?
    public private(set) var outlet: String?
    public private(set) var expressions: [String: String]
    public internal(set) var constants: [String: Any]
    private var _originalExpressions: [String: String]

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
        self.state = try! unwrap(state)
        self.constants = constants
        self.expressions = expressions
        self.children = children

        _originalExpressions = expressions

        super.init()

        overrideExpressions()
        updateVariables()

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
    }

    // MARK: Validation

    public static func isValidExpressionName(
        _ name: String, for viewOrViewControllerClass: AnyClass) -> Bool {
        switch name {
        case "top", "left", "bottom", "right", "width", "height":
            return true
        default:
            if let viewClass = viewOrViewControllerClass as? UIView.Type {
                return viewClass.cachedExpressionTypes[name] != nil
            } else if let viewControllerClass = viewOrViewControllerClass as? UIViewController.Type {
                return viewControllerClass.cachedExpressionTypes[name] != nil
            }
            preconditionFailure("\(viewOrViewControllerClass) is not a UIView or UIViewController subclass")
        }
    }

    /// Perform pre-validation on the node and (optionally) its children
    public func validate(recursive: Bool = true) -> Set<LayoutError> {
        var errors = Set<LayoutError>()
        for name in expressions.keys {
            guard let expression = self.expression(for: name) else {
                errors.insert(LayoutError(SymbolError("Unknown expression name `\(name)`", for: name), for: self))
                continue
            }
            do {
                // TODO: check for recursion here?
                _ = try expression.evaluate()
            } catch {
                errors.insert(LayoutError(error, for: self))
            }
        }
        errors.formUnion(redundantExpressionErrors())
        if recursive {
            for child in children {
                errors.formUnion(child.validate())
            }
        }
        return errors
    }

    private func redundantExpressionErrors() -> Set<LayoutError> {
        var errors = Set<LayoutError>()
        if !(expressions["bottom"] ?? "").isEmpty,
            !value(forSymbol: "height", dependsOn: "bottom"),
            !value(forSymbol: "top", dependsOn: "bottom") {
            errors.insert(LayoutError(SymbolError("Expression for `bottom` is redundant",
                                                  for: "bottom"), for: self))
        }
        if !(expressions["right"] ?? "").isEmpty,
            !value(forSymbol: "width", dependsOn: "right"),
            !value(forSymbol: "left", dependsOn: "right") {
            errors.insert(LayoutError(SymbolError("Expression for `right` is redundant",
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

    private func bubbleUnhandledError() {
        guard let error = _unhandledError else { return }

        if let parent = parent {
            parent._unhandledError = LayoutError(error, for: parent)
            _unhandledError = nil
            parent.bubbleUnhandledError()
        }

        if let delegate = _owner as? LayoutDelegate {
            delegate.layoutNode(self, didDetectError: LayoutError(error))
            _unhandledError = nil
            return
        }

        if var responder: UIResponder = viewController {
            // Pass error up the chain to the first VC that can handle it
            while let nextResponder = responder.next {
                if let delegate = nextResponder as? LayoutDelegate {
                    delegate.layoutNode(self, didDetectError: LayoutError(error))
                    _unhandledError = nil
                    return
                }
                responder = nextResponder
            }
        }
    }

    internal func logError(_ error: Error) {
        _unhandledError = LayoutError(error, for: self)

        #if arch(i386) || arch(x86_64)
            print("Error: \(_unhandledError!)")
        #endif

        bubbleUnhandledError()
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

    private func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        if let lhs = lhs as? AnyHashable, let rhs = rhs as? AnyHashable {
            return lhs == rhs
        }
        return false // Can't compare equality
    }

    public var state: Any {
        didSet {
            var equal = true
            if let newState = state as? [String: Any], var oldState = oldValue as? [String: Any] {
                for (key, value) in newState {
                    guard let oldValue = oldState[key] else {
                        preconditionFailure("Cannot add new keys to state after initialization")
                    }
                    equal = equal && areEqual(oldValue, value)
                    oldState[key] = value
                }
                state = oldState
            } else {
                state = try! unwrap(state)
                let oldType = type(of: oldValue)
                assert(oldType == Void.self || oldType == type(of: state), "Cannot change type of state after initialization")
                equal = areEqual(oldValue, state)
            }
            if !equal {
                updateVariables()
            }
        }
    }

    private var _variables = [String: Any]()
    private func updateVariables() {
        var equal = true
        if let members = state as? [String: Any] {
            equal = false // Shouldn't get here otherwise
            _variables = members
        } else {
            // TODO: flatten nested objects
            let mirror = Mirror(reflecting: state)
            for (name, value) in mirror.children {
                if let name = name, (equal && areEqual(_variables[name] as Any, value)) == false {
                    _variables[name] = value
                    equal = false
                }
            }
        }
        if !equal {
            // TODO: work out which expressions are actually affected
            attempt(update)
        }
    }

    // MARK: Hierarchy

    public private(set) var children: [LayoutNode]
    public private(set) weak var parent: LayoutNode? {
        didSet {
            _getters.removeAll()
            _cachedExpressions.removeAll()
            bubbleUnhandledError()
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

        for (name, expression) in node._originalExpressions where _originalExpressions[name] == nil {
            _originalExpressions[name] = expression
        }
        expressions = _originalExpressions
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

        // Handle Autolayout
        if let widthConstraint = _widthConstraint {
            view.removeConstraint(widthConstraint)
            _widthConstraint = nil
        }
        if let heightConstraint = _heightConstraint {
            view.removeConstraint(heightConstraint)
            _heightConstraint = nil
        }
        if !view.constraints.isEmpty {
            for constraint in view.constraints where constraint.priority == UILayoutPriorityRequired {
                // Prevent priority conflicts with Layout constraints
                // TODO: can we limit this only to constraints that affect width/height?
                constraint.priority -= 1
            }
            if expressions["width"] != nil {
                _widthConstraint = view.widthAnchor.constraint(equalToConstant: 0)
            }
            if expressions["height"] != nil {
                _heightConstraint = view.heightAnchor.constraint(equalToConstant: 0)
            }
        }
    }

    private var _evaluating = [String]()
    private var _cachedExpressions = [String: LayoutExpression]()
    private func expression(for symbol: String) -> LayoutExpression? {
        if let expression = _cachedExpressions[symbol] {
            return expression.isVoid ? nil : expression
        }
        if let string = expressions[symbol] {
            var expression: LayoutExpression
            switch symbol {
            case "left", "right":
                expression = LayoutExpression(xExpression: string, for: self)
            case "top", "bottom":
                expression = LayoutExpression(yExpression: string, for: self)
            case "width", "contentSize.width":
                expression = LayoutExpression(widthExpression: string, for: self)
            case "height", "contentSize.height":
                expression = LayoutExpression(heightExpression: string, for: self)
            default:
                guard let type = viewControllerExpressionTypes[symbol] ?? viewExpressionTypes[symbol] else {
                    expression = .void // NOTE: if we don't set the expression variable, the app crashes (Swift bug?)
                    _cachedExpressions[symbol] = expression
                    return nil
                }
                if case let .any(kind) = type.type, kind is CGFloat.Type {
                    // Allow use of % in any vertical/horizontal property expression
                    let parts = symbol.components(separatedBy: ".")
                    if ["left", "right", "x", "width"].contains(parts.last!) {
                        expression = LayoutExpression(xExpression: string, for: self)
                    } else if ["top", "bottom", "y", "height"].contains(parts.last!) {
                        expression = LayoutExpression(yExpression: string, for: self)
                    } else {
                        expression = LayoutExpression(expression: string, ofType: type, for: self)
                    }
                } else {
                    expression = LayoutExpression(expression: string, ofType: type, for: self)
                }
            }
            // Optimize constant expressions
            func isConstant(_ exp: LayoutExpression) -> Bool {
                for name in expression.symbols {
                    guard expressions[name] != nil else {
                        guard value(forVariable: name) == nil else {
                            return false // Inherited variable
                        }
                        guard value(forConstant: name) == nil else {
                            continue // Inherited constant
                        }
                        return false // View or controller property
                    }
                    if _evaluating.contains(name) {
                        return false // Possible circular reference
                    }
                    _evaluating.append(name)
                    defer { _evaluating.removeLast() }
                    if let expression = self.expression(for: name) {
                        if !isConstant(expression) {
                            return false
                        }
                    }
                }
                return true
            }
            if isConstant(expression) {
                _evaluating.append(symbol)
                defer { _evaluating.removeLast() }
                do {
                    let value = try expression.evaluate()
                    try setValue(value, forExpression: symbol)
                    expression = LayoutExpression(evaluate: { value }, symbols: [])
                } catch {
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

    private func value(forVariable name: String) -> Any? {
        return _variables[name] ?? parent?.value(forVariable: name)
    }

    public lazy var viewExpressionTypes: [String: RuntimeType] = {
        return type(of: self.view).cachedExpressionTypes
    }()

    public lazy var viewControllerExpressionTypes: [String: RuntimeType] = {
        return self.viewController.map { type(of: $0).cachedExpressionTypes } ?? [:]
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
        if let expression = self.expression(for: name) {
            for name in expression.symbols where name == symbol || value(forSymbol: name, dependsOn: symbol) {
                return true
            }
        }
        return false
    }

    // Note: thrown error is always a SymbolError
    func doubleValue(forSymbol symbol: String) throws -> Double {
        let anyValue = try value(forSymbol: symbol)
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

    // Return the best available VC for computing the layout guide
    private var _layoutGuideController: UIViewController? {
        let controller = view.viewController
        return controller?.tabBarController?.selectedViewController ??
            controller?.navigationController?.topViewController ?? controller
    }

    // Note: thrown error is always a SymbolError
    // TODO: numeric values may be returned as a Double, even if original type was something else
    // this was deliberate for performance reasons, but it's a bit confusing - find a better solution
    // before making this API public
    private var _getters = [String: () throws -> Any]()
    func value(forSymbol symbol: String) throws -> Any {
        if let getter = _getters[symbol] {
            return try SymbolError.wrap(getter, for: symbol)
        }
        let getter: () throws -> Any
        if let expression = self.expression(for: symbol) {
            getter = { [unowned self] in
                if self._evaluating.last == symbol,
                    let value = self.value(forVariable: symbol) ?? self.value(forConstant: symbol) {
                    // If an expression directly references itself it may be shadowing
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
        } else {
            switch symbol {
            case "left":
                getter = (parent == nil) ? { [unowned self] in self.view.frame.minX } : { 0 }
            case "width":
                getter = { [unowned self] in self.frame.width }
            case "right":
                getter = { [unowned self] in self.frame.maxX }
            case "top":
                getter = (parent == nil) ? { [unowned self] in self.view.frame.minY } : { 0 }
            case "height":
                getter = { [unowned self] in self.frame.height }
            case "bottom":
                getter = { [unowned self] in self.frame.maxY }
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
                        getter = { [unowned self] in try self.parent?.value(forSymbol: tail) ?? 0 }
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
                        // Try local variables/constants first, then
                        if let value = self.value(forVariable: symbol) ?? self.value(forConstant: symbol) {
                            return value
                        }
                        // Then controller/view symbols
                        if let value =
                            self.viewController?.value(forSymbol: symbol) ?? self.view.value(forSymbol: symbol) {
                            return value
                        }
                        throw SymbolError("\(symbol) not found", for: symbol)
                    }
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
            let anyValue = try value(forSymbol: name)
            try setValue(anyValue, forExpression: name)
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
            if expressions["contentSize"] != nil, !_evaluating.contains("contentSize") {
                return try value(forSymbol: "contentSize") as! CGSize
            }
            // Try AutoLayout
            if _widthConstraint != nil || _heightConstraint != nil {
                let transform = view.layer.transform
                view.layer.transform = CATransform3DIdentity
                let frame = view.frame
                view.translatesAutoresizingMaskIntoConstraints = false
                if let widthConstraint = _widthConstraint,
                    expressions["contentSize.width"] != nil, !_evaluating.contains("contentSize.width") {
                    widthConstraint.isActive = true
                    widthConstraint.constant = try CGFloat(doubleValue(forSymbol: "contentSize.width"))
                } else if let widthConstraint = _widthConstraint, !_evaluating.contains("width") {
                    widthConstraint.isActive = true
                    widthConstraint.constant = try CGFloat(doubleValue(forSymbol: "width"))
                } else {
                    _widthConstraint?.isActive = false
                }
                if let heightConstraint = _heightConstraint,
                    expressions["contentSize.height"] != nil, !_evaluating.contains("contentSize.height") {
                    heightConstraint.isActive = true
                    heightConstraint.constant = try CGFloat(doubleValue(forSymbol: "contentSize.height"))
                } else if let heightConstraint = _heightConstraint, !_evaluating.contains("height") {
                    heightConstraint.isActive = true
                    heightConstraint.constant = try CGFloat(doubleValue(forSymbol: "height"))
                } else {
                    _heightConstraint?.isActive = false
                }
                view.layoutIfNeeded()
                let size = view.frame.size
                _widthConstraint?.isActive = false
                _heightConstraint?.isActive = false
                view.translatesAutoresizingMaskIntoConstraints = true
                view.frame = frame
                view.layer.transform = transform
                return size
            }
            // Try intrinsic size
            let intrinsicSize = view.intrinsicContentSize
            var size = intrinsicSize
            if size.width != UIViewNoIntrinsicMetric || size.height != UIViewNoIntrinsicMetric {
                var targetSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
                if expressions["contentSize.width"] != nil, !_evaluating.contains("contentSize.width") {
                    targetSize.width = try CGFloat(doubleValue(forSymbol: "contentSize.width"))
                } else if !_evaluating.contains("width") {
                    targetSize.width = try CGFloat(doubleValue(forSymbol: "width"))
                }
                if expressions["contentSize.height"] != nil, !_evaluating.contains("contentSize.height") {
                    targetSize.height = try CGFloat(doubleValue(forSymbol: "contentSize.height"))
                } else if !_evaluating.contains("height") {
                    targetSize.height = try CGFloat(doubleValue(forSymbol: "height"))
                }
                if targetSize.width < intrinsicSize.width || targetSize.height < intrinsicSize.height {
                    size = view.systemLayoutSizeFitting(targetSize)
                }
                return size
            }
            // Try best fit for subviews
            for child in children where !child.isHidden {
                let frame = child.frame
                size.width = max(size.width, frame.maxX)
                size.height = max(size.height, frame.maxY)
            }
            // Fill superview
            if size.width <= 0, size.height <= 0 {
                size = view.superview?.bounds.size ?? .zero
            }
            if expressions["contentSize.width"] != nil, !_evaluating.contains("contentSize.width") {
                size.width = try CGFloat(doubleValue(forSymbol: "contentSize.width"))
            } else if expressions["contentSize.height"] != nil, !_evaluating.contains("contentSize.height") {
                size.height = try CGFloat(doubleValue(forSymbol: "contentSize.height"))
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
        let transform = view.layer.transform
        view.layer.transform = CATransform3DIdentity
        view.frame = frame
        view.layer.transform = transform
        view.didUpdateLayout(for: self)
        view.viewController?.didUpdateLayout(for: self)
        try throwUnhandledError()
    }

    // MARK: binding

    // Note: thrown error is always a LayoutError
    public func mount(in viewController: UIViewController) throws {
        guard parent == nil else {
            throw LayoutError.message("The `mount()` method should only be used on a root node.")
        }
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
    private weak var _owner: NSObject?
    private func bind(to owner: NSObject) throws {
        guard _owner == nil || _owner == owner else {
            throw LayoutError.message("Cannot re-bind an already bound node.")
        }
        if let viewController = viewController, owner != viewController {
            do {
                try bind(to: viewController)
                return
            } catch {}
        }
        _owner = owner
        if let outlet = outlet {
            guard let type = type(of: owner).allPropertyTypes()[outlet] else {
                throw LayoutError.message("`\(type(of: owner))` does not have an outlet named `\(outlet)`")
            }
            var didMatch = false
            var expectedType = "UIView or LayoutNode"
            if viewController != nil {
                expectedType = "UIViewController, \(expectedType)"
            }
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
            } else if let viewController = viewController, type.matches(UIViewController.self) {
                if type.matches(viewController) {
                    owner.setValue(viewController, forKey: outlet)
                    didMatch = true
                } else {
                    expectedType = "\(type(of: viewController))"
                }
            }
            if !didMatch {
                throw LayoutError.message("outlet `\(outlet)` of `\(type(of: owner))` is not a \(expectedType)")
            }
        }
        if let type = viewExpressionTypes["delegate"],
            view.value(forKey: "delegate") == nil, type.matches(owner) {
                view.setValue(owner, forKey: "delegate")
        }
        if let type = viewExpressionTypes["dataSource"],
            view.value(forKey: "dataSource") == nil, type.matches(owner) {
                view.setValue(owner, forKey: "dataSource")
        }
        for child in children {
            try child.bind(to: owner)
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
