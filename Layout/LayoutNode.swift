//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

/// LayoutNode represents a single node of a layout tree
/// The LayoutNode retains its view/view controller, so any references
/// from the view back to the node should be weak
public class LayoutNode: NSObject {

    /// The view managed by this node
    /// Accessing this property will create the view if it doesn't already exist
    public var view: UIView {
        attempt(setUpExpressions)
        return _view
    }

    /// The (optional) view controller managed by this node
    /// Accessing this property will create the view controller if it doesn't already exist
    public var viewController: UIViewController? {
        if _class is UIViewController.Type {
            attempt(setUpExpressions)
        }
        return _viewController
    }

    /// All top-level view controllers belonging to this node or its children
    /// These should be added as child view controllers to the node's parent view controller
    /// Accessing this property will instantiate the view hierarchy if it doesn't already exist
    public var viewControllers: [UIViewController] {
        guard let viewController = viewController else {
            return children.flatMap { $0.viewControllers }
        }
        return [viewController]
    }

    /// The name of an outlet belonging to the nodes' owne that the node should bind to
    public private(set) var outlet: String?

    /// The expressions used to initialized the node
    public private(set) var expressions: [String: String]

    /// Constants that can be referenced by expressions in the node and its children
    public internal(set) var constants: [String: Any]

    // The delegate used for handling errors
    // Normally this is the same as the owner, but it can be overridden in special cases
    private weak var _delegate: LayoutDelegate?
    weak var delegate: LayoutDelegate? {
        get {
            return _delegate ??
                (_owner as? LayoutDelegate) ??
                (viewController as? LayoutDelegate) ??
                (_view as? LayoutDelegate) ??
                parent?.delegate
        }
        set {
            _delegate = newValue
        }
    }

    private func delegate(for selector: Selector) -> LayoutDelegate? {
        var delegate = self.delegate
        var responder = delegate as? UIResponder
        while delegate != nil || responder != nil {
            if (delegate as AnyObject).responds(to: selector) {
                return delegate
            }
            responder = responder?.next
            delegate = responder as? LayoutDelegate
        }
        return parent?.delegate(for: selector)
    }

    /// Get the view class without side-effects of accessing view
    var viewClass: UIView.Type { return _class as? UIView.Type ?? UIView.self }

    /// Get the view controller class without side-effects of accessing view
    var viewControllerClass: UIViewController.Type? { return _class as? UIViewController.Type }

    // For internal use
    private(set) var _class: AnyClass
    @objc var _view: UIView!
    private(set) var _viewController: UIViewController?
    private(set) var _originalExpressions: [String: String]
    var _parameters: [String: RuntimeType]

    private var _setupComplete = false
    private func completeSetup() throws {
        guard !_setupComplete else { return }
        _setupComplete = true

        if _view == nil {
            if let controllerClass = viewControllerClass {
                _viewController = try controllerClass.create(with: self)
                _view = _viewController!.view
            } else {
                _view = try viewClass.create(with: self)
                assert(_view != nil)
            }
        }

        setUpAutoLayout()
        overrideExpressions()
        _ = updateVariables()
        updateObservers()

        for (index, child) in children.enumerated() {
            child.parent = self
            if let viewController = _view.viewController {
                viewController.didInsertChildNode(child, at: index)
            } else {
                _view.didInsertChildNode(child, at: index)
            }
        }
    }

    private var _observing = false
    private func updateObservers() {
        if _observing, parent != nil {
            stopObserving()
        } else if !_observing, parent == nil {
            NotificationCenter.default.addObserver(self, selector: #selector(contentSizeChanged), name: .UIContentSizeCategoryDidChange, object: nil)
            addObserver(self, forKeyPath: "_view.frame", options: [], context: nil)
            addObserver(self, forKeyPath: "_view.bounds", options: .old, context: nil)
            _observing = true
        }
    }

    private func stopObserving() {
        if _observing {
            NotificationCenter.default.removeObserver(self)
            removeObserver(self, forKeyPath: "_view.frame")
            removeObserver(self, forKeyPath: "_view.bounds")
            _observing = false
        }
    }

    public override func observeValue(
        forKeyPath keyPath: String?,
        of _: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        if let change = change, let old = change[.oldKey] as? CGRect, old.size == _view.bounds.size {
            return
        }
        attempt(update)
    }

    @objc private func contentSizeChanged() {
        guard _setupComplete else {
            return
        }
        cleanUp()
        attempt(update)
    }

    // Create the node using a UIView or UIViewController subclass
    // TODO: is there any reason not to make this public?
    init(
        class: AnyClass,
        outlet: String? = nil,
        state: Any = (),
        constants: [String: Any]...,
        expressions: [String: String] = [:],
        children: [LayoutNode] = []
    ) throws {
        guard `class` is UIView.Type || `class` is UIViewController.Type else {
            throw LayoutError.message("\(`class`) is not a subclass of UIView or UIViewController")
        }
        _class = `class`
        _state = try! unwrap(state)
        self.outlet = outlet
        self.constants = merge(constants)
        self.expressions = expressions
        self.children = children

        _parameters = [:]
        _originalExpressions = expressions

        super.init()
    }

    /// Create a node for managing a view controller instance
    public convenience init(
        viewController: UIViewController,
        outlet: String? = nil,
        state: Any = (),
        constants: [String: Any]...,
        expressions: [String: String] = [:],
        children: [LayoutNode] = []
    ) {
        assert(Thread.isMainThread)

        try! self.init(
            class: viewController.classForCoder,
            outlet: outlet,
            state: state,
            constants: merge(constants),
            expressions: expressions,
            children: children
        )

        _viewController = viewController
        _view = viewController.view
    }

    /// Create a node for managing a view instance
    public convenience init(
        view: UIView? = nil,
        outlet: String? = nil,
        state: Any = (),
        constants: [String: Any]...,
        expressions: [String: String] = [:],
        children: [LayoutNode] = []
    ) {
        assert(Thread.isMainThread)

        try! self.init(
            class: view?.classForCoder ?? UIView.self,
            outlet: outlet,
            state: state,
            constants: merge(constants),
            expressions: expressions,
            children: children
        )

        _view = view
    }

    deinit {
        stopObserving()
    }

    // MARK: Validation

    /// Test if the specified expression is valid for a given view or view controller class
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
    /// Returns a set of LayoutError's, or an empty set if the node is valid
    public func validate(recursive: Bool = true) -> Set<LayoutError> {
        var errors = Set<LayoutError>()
        do {
            try setUpExpressions()
        } catch {
            errors.insert(LayoutError(error, for: self))
        }
        for name in expressions.keys {
            do {
                _ = try _getters[name]?()
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
            errors.insert(LayoutError(SymbolError("Expression for bottom is redundant",
                                                  for: "bottom"), for: self))
        }
        if !(expressions["right"] ?? "").isEmpty,
            !value(forSymbol: "width", dependsOn: "right"),
            !value(forSymbol: "left", dependsOn: "right") {
            errors.insert(LayoutError(SymbolError("Expression for right is redundant",
                                                  for: "right"), for: self))
        }
        return errors
    }

    private var _unhandledError: LayoutError?
    private func throwUnhandledError() throws {
        try _unhandledError.map {
            if $0.isTransient {
                _unhandledError = nil
            }
            unbind()
            throw $0
        }
    }

    private func bubbleUnhandledError() {
        guard let error = _unhandledError else {
            return
        }
        if let parent = parent {
            if parent._unhandledError == nil ||
                (parent._unhandledError?.isTransient == true && !error.isTransient) {
                parent._unhandledError = LayoutError(error, for: parent)
                if error.isTransient {
                    _unhandledError = nil
                }
                parent.bubbleUnhandledError()
            }
            return
        }
        if let delegate = self.delegate(for: #selector(LayoutDelegate.layoutNode(_:didDetectError:))) {
            if error.isTransient {
                _unhandledError = nil
            }
            delegate.layoutNode?(self, didDetectError: error)
        }
    }

    func attempt<T>(_ closure: () throws -> T) -> T? {
        do {
            return try closure()
        } catch {
            let error = LayoutError(error, for: self)
            if _unhandledError == nil || (_unhandledError?.isTransient == true && !error.isTransient) {
                _unhandledError = error
                // Don't bubble if we're in the middle of evaluating an expression
                if _evaluating.isEmpty {
                    bubbleUnhandledError()
                }
            }
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

    private var _state: Any

    /// Update the node state and re-evaluate any expressions that are affected
    /// There is no need to call `update()` after setting the state as it is done automatically
    public func setState(_ newState: Any) {
        var equal = true
        if let newState = newState as? [String: Any], var oldState = _state as? [String: Any] {
            for (key, value) in newState {
                guard let oldValue = oldState[key] else {
                    preconditionFailure("Cannot add new keys to state after initialization")
                }
                equal = equal && areEqual(oldValue, value)
                oldState[key] = value
            }
            _state = oldState
        } else {
            let oldState = _state
            _state = try! unwrap(newState)
            let oldType = type(of: oldState)
            assert(oldType == Void.self || oldType == type(of: _state), "Cannot change type of state after initialization")
            equal = areEqual(oldState, _state)
        }
        if !equal, updateVariables() {
            // TODO: work out which expressions are actually affected
            attempt(update)
        }
    }

    @available(*, deprecated, message: "Use setState() instead")
    @nonobjc public var state: Any {
        set { setState(newValue) }
        get { return _state }
    }

    private var _variables = [String: Any]()
    private func updateVariables() -> Bool {
        if let members = _state as? [String: Any] {
            _variables = members
            return true
        }
        // TODO: what about nested objects?
        var equal = true
        let mirror = Mirror(reflecting: _state)
        for (name, value) in mirror.children {
            if let name = name, (equal && areEqual(_variables[name] as Any, value)) == false {
                _variables[name] = value
                equal = false
            }
        }
        return !equal
    }

    // MARK: Hierarchy

    /// The immediate child-nodes of this layout (retained)
    public private(set) var children: [LayoutNode]

    /// The parent node of this layout (unretained)
    public private(set) weak var parent: LayoutNode? {
        didSet {
            if let parent = parent, parent._setupComplete {
                parent._widthDependsOnParent = nil
                parent._heightDependsOnParent = nil
            }
            if _setupComplete {
                cleanUp()
                overrideExpressions()
                bubbleUnhandledError()
                updateObservers()
            }
        }
    }

    /// The previous sibling of the node within its parent
    /// Returns nil if this is a root node, or is the first child of its parent
    var previous: LayoutNode? {
        if let siblings = parent?.children, let index = siblings.index(where: { $0 === self }), index > 0 {
            return siblings[index - 1]
        }
        return nil
    }

    /// The next sibling of the node within its parent
    /// Returns nil if this is a root node, or is the last child of its parent
    var next: LayoutNode? {
        if let siblings = parent?.children, let index = siblings.index(where: { $0 === self }),
            index < siblings.count - 1 {
            return siblings[index + 1]
        }
        return nil
    }

    /// Appends a new child node to this node's children
    /// Note: this will not necessarily trigger an update
    public func addChild(_ child: LayoutNode) {
        insertChild(child, at: children.count)
    }

    /// Inserts a new child node at the specified index
    /// Note: this will not necessarily trigger an update
    public func insertChild(_ child: LayoutNode, at index: Int) {
        child.removeFromParent()
        children.insert(child, at: index)
        if _setupComplete {
            child.parent = self
            if let owner = _owner {
                try? child.bind(to: owner)
            }
            if let viewController = _viewController {
                viewController.didInsertChildNode(child, at: index)
            } else {
                _view.didInsertChildNode(child, at: index)
            }
        }
    }

    /// Replaces the child node at the specified index with this one
    /// Note: this will not necessarily trigger an update
    public func replaceChild(at index: Int, with child: LayoutNode) {
        children[index].removeFromParent()
        insertChild(child, at: index)
    }

    /// Removes the node from its parent
    /// Note: this will not necessarily trigger an update in either node
    public func removeFromParent() {
        if let index = parent?.children.index(where: { $0 === self }) {
            if let viewController = parent?._viewController {
                viewController.willRemoveChildNode(self, at: index)
            } else {
                parent?._view.willRemoveChildNode(self, at: index)
            }
            unbind()
            parent?.children.remove(at: index)
            parent = nil
            return
        }
        _view?.removeFromSuperview()
        for controller in viewControllers {
            controller.removeFromParentViewController()
        }
    }

    // Experimental - used for nested XML reference loading
    internal func update(with layout: Layout) throws {
        let newClass: AnyClass = try layout.getClass()
        let oldClass: AnyClass = _class
        guard newClass.isSubclass(of: oldClass) else {
            throw LayoutError("Cannot replace \(oldClass) with \(newClass)", for: self)
        }

        for child in children {
            child.removeFromParent()
        }

        if newClass != oldClass {
            stopObserving()

            let oldView = _view
            _view = nil

            let oldViewController = _viewController
            _viewController = nil

            _class = newClass
            viewExpressionTypes = viewClass.cachedExpressionTypes
            viewControllerClass.map {
                self.viewControllerExpressionTypes = $0.cachedExpressionTypes
            }

            if _setupComplete {

                // NOTE: this convoluted update process is needed to ensure that if the
                // class changes, the new view or controller is inserted at the correct
                // position in the hierarchy

                _setupComplete = false

                (_widthConstraint as NSLayoutConstraint?).map {
                    oldView?.removeConstraint($0)
                    _widthConstraint = nil
                }
                (_heightConstraint as NSLayoutConstraint?).map {
                    oldView?.removeConstraint($0)
                    _heightConstraint = nil
                }

                unmount()
                if let parent = parent, let index = parent.children.index(of: self) {
                    oldView?.removeFromSuperview()
                    oldViewController?.removeFromParentViewController()
                    parent.insertChild(self, at: index)
                } else if let superview = oldView?.superview,
                    let index = superview.subviews.index(of: oldView!) {
                    if let parentViewController = oldViewController?.parent {
                        oldViewController?.removeFromParentViewController()
                        parentViewController.addChildViewController(viewController!)
                    }
                    oldView!.removeFromSuperview()
                    superview.insertSubview(view, at: index)
                }
            }
        }

        for (name, expression) in layout.expressions where _originalExpressions[name] == nil {
            _originalExpressions[name] = expression
        }

        if _setupComplete {
            cleanUp()
            overrideExpressions()
        }

        if let outlet = layout.outlet {
            self.outlet = outlet
            try LayoutError.wrap({ try _owner.map { try bind(to: $0) } }, for: self)
        }

        for child in layout.children {
            addChild(try LayoutNode(layout: child))
        }
        if _setupComplete, _view.window != nil || _owner != nil {
            try update()
        }
    }

    // MARK: expressions

    private func overrideExpressions() {
        assert(_setupComplete && _view != nil)
        expressions = _originalExpressions

        // layout props
        if expressions["width"] == nil {
            if expressions["left"] != nil, expressions["right"] != nil {
                expressions["width"] = "right - left"
            } else if !(_view is UIScrollView),
                _usesAutoLayout || _view.intrinsicContentSize.width != UIViewNoIntrinsicMetric {
                expressions["width"] = "auto"
            } else if parent != nil {
                expressions["width"] = "100%"
            }
        }
        if expressions["left"] == nil {
            if expressions["right"] != nil {
                expressions["left"] = "right - width"
            } else if parent != nil {
                expressions["left"] = "0"
            }
        }
        if expressions["height"] == nil {
            if _class is UIStackView.Type {
                expressions["height"] = "auto" // TODO: remove special case
            } else if expressions["top"] != nil, expressions["bottom"] != nil {
                expressions["height"] = "bottom - top"
            }  else if !(_view is UIScrollView),
                _usesAutoLayout || _view.intrinsicContentSize.height != UIViewNoIntrinsicMetric {
                expressions["height"] = "auto"
            } else if parent != nil {
                expressions["height"] = "100%"
            }
        }
        if expressions["top"] == nil {
            if expressions["bottom"] != nil {
                expressions["top"] = "bottom - height"
            } else if parent != nil {
                expressions["top"] = "0"
            }
        }
    }

    private func clearCachedValues() {
        for fn in _valueClearers { fn() }
    }

    private func cleanUp() {
        assert(_evaluating.isEmpty)
        if let error = _unhandledError, error.isTransient {
            _unhandledError = nil
        }
        _widthDependsOnParent = nil
        _heightDependsOnParent = nil
        _getters.removeAll()
        _layoutExpressions.removeAll()
        _viewControllerExpressions.removeAll()
        _viewExpressions.removeAll()
        _valueClearers.removeAll()
        for child in children {
            child.cleanUp()
        }
    }

    private var _evaluating = [String]()
    private var _getters = [String: () throws -> Any]()
    private var _layoutExpressions = [String: LayoutExpression]()
    private var _viewControllerExpressions = [String: LayoutExpression]()
    private var _viewExpressions = [String: LayoutExpression]()
    private var _valueClearers = [() -> Void]()

    // Note: thrown error is always a SymbolError
    private func setUpExpressions() throws {
        guard _getters.isEmpty else {
            return
        }
        try completeSetup()
        for (symbol, string) in expressions {
            var expression: LayoutExpression
            var isViewControllerExpression = false
            var isViewExpression = false
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
                let type: RuntimeType
                if let viewControllerType = viewControllerExpressionTypes[symbol] {
                    isViewControllerExpression = true
                    type = viewControllerType
                } else if let viewType = viewExpressionTypes[symbol] {
                    isViewExpression = true
                    type = viewType
                } else if let parameterType = _parameters[symbol] {
                    type = parameterType
                } else {
                    throw SymbolError("Unknown property \(symbol)", for: symbol)
                }
                switch type.availability {
                case .available:
                    break
                case let .unavailable(reason):
                    throw SymbolError("\(_class).\(symbol) is not available in Layout\(reason.map { ". \($0)" } ?? "")", for: symbol)
                }
                if case let .any(kind) = type.type, kind is CGFloat.Type {
                    switch symbol {
                    case "contentSize.width":
                        expression = LayoutExpression(contentWidthExpression: string, for: self)
                    case "contentSize.height":
                        expression = LayoutExpression(contentHeightExpression: string, for: self)
                    default:
                        // Allow use of % in any vertical/horizontal property expression
                        let parts = symbol.components(separatedBy: ".")
                        if ["left", "right", "x", "width"].contains(parts.last!) {
                            expression = LayoutExpression(xExpression: string, for: self)
                        } else if ["top", "bottom", "y", "height"].contains(parts.last!) {
                            expression = LayoutExpression(yExpression: string, for: self)
                        } else {
                            expression = LayoutExpression(expression: string, type: type, for: self)
                        }
                    }
                } else {
                    expression = LayoutExpression(expression: string, type: type, for: self)
                }
            }
            // Only set constant values once
            if expression.symbols.isEmpty {
                do {
                    let value = try expression.evaluate()
                    if isViewControllerExpression {
                        try _viewController?.setValue(value, forExpression: symbol)
                    } else if isViewExpression {
                        try _view.setValue(value, forExpression: symbol)
                    }
                    _getters[symbol] = { value }
                    continue // Don't add to expressions arrays for re-evaluations
                } catch {
                    // Something went wrong
                    expression = LayoutExpression(
                        evaluate: { throw SymbolError(error, for: symbol) },
                        symbols: []
                    )
                }
            } else {
                var cachedValue: Any?
                _valueClearers.append {
                    cachedValue = nil
                }
                let evaluate = expression.evaluate
                expression = LayoutExpression(
                    evaluate: { [unowned self] in
                        if let value = cachedValue {
                            return value
                        }
                        guard !self._evaluating.contains(symbol) else {
                            // If an expression directly references itself it may be shadowing
                            // a constant or variable, so check for that first before throwing
                            if self._evaluating.last == symbol,
                                let value = try self.value(forVariableOrConstant: symbol) {
                                return value
                            }
                            throw SymbolError("Expression for \(symbol) references a nonexistent symbol of the same name (expressions cannot reference themselves)", for: symbol)
                        }
                        self._evaluating.append(symbol)
                        defer {
                            assert(self._evaluating.last == symbol)
                            self._evaluating.removeLast()
                        }
                        let value = try SymbolError.wrap(evaluate, for: symbol)
                        cachedValue = value
                        return value
                    },
                    symbols: expression.symbols
                )
            }
            // Store getters and expressions
            _getters[symbol] = expression.evaluate
            if isViewControllerExpression {
                _viewControllerExpressions[symbol] = expression
            } else if isViewExpression {
                _viewExpressions[symbol] = expression
            } else {
                _layoutExpressions[symbol] = expression
            }
        }

        #if arch(i386) || arch(x86_64)

            // Validate expressions
            for error in redundantExpressionErrors() {
                throw error
            }

        #endif
    }

    // MARK: symbols

    private func localizedString(forKey key: String) throws -> String {
        guard let delegate = self.delegate(for: #selector(LayoutDelegate.layoutNode(_:localizedStringForKey:))) else {
            throw SymbolError("No layoutNode(_:localizedStringForKey:) implementation found. Unable to look up localized string", for: key)
        }
        guard let string = delegate.layoutNode?(self, localizedStringForKey: key) else {
            throw SymbolError("Missing localized string", for: key)
        }
        return string
    }

    // Note: thrown error is always a SymbolError
    private func value(forParameter name: String) throws -> Any? {
        guard _parameters[name] != nil else {
            return nil
        }
        guard let getter = _getters[name] else {
            throw SymbolError("Missing value for parameter \(name)", for: name)
        }
        return try getter()
    }

    private func value(forKeyPath keyPath: String, in dictionary: [String: Any]) -> Any? {
        if let value = dictionary[keyPath] {
            return value
        }
        guard let range = keyPath.range(of: ".") else {
            return nil
        }
        let key = keyPath.substring(to: range.lowerBound)
        // TODO: if not a dictionary, should we use a mirror?
        if let dictionary = dictionary[key] as? [String: Any] {
            return value(forKeyPath: keyPath.substring(from: range.upperBound), in: dictionary)
        }
        return nil
    }

    // Used by LayoutExpression
    func value(forConstant name: String) -> Any? {
        guard value(forKeyPath: name, in: _variables) == nil else {
            return nil
        }
        if let value = value(forKeyPath: name, in: constants) ?? parent?.value(forConstant: name) {
            return value
        }
        if name.hasPrefix("strings.") {
            let key = name.substring(from: "strings.".endIndex)
            return attempt({ try localizedString(forKey: key) })
        }
        // TODO: should we check the delegate as well?
        return nil
    }

    func value(forVariableOrConstant name: String) throws -> Any? {
        if let value = try value(forParameter: name) ??
            value(forKeyPath: name, in: _variables) ??
            value(forKeyPath: name, in: constants) ??
            parent?.value(forVariableOrConstant: name) {
            return value
        }
        guard let delegate = _delegate else {
            return nil
        }
        return delegate.value?(forVariableOrConstant: name)
    }

    public lazy var viewExpressionTypes: [String: RuntimeType] = {
        self.viewClass.cachedExpressionTypes
    }()

    public lazy var viewControllerExpressionTypes: [String: RuntimeType] = {
        self.viewControllerClass.map { $0.cachedExpressionTypes } ?? [:]
    }()

    private class func isLayoutSymbol(_ name: String) -> Bool {
        switch name {
        case "left", "right", "width", "top", "bottom", "height":
            return true
        default:
            return false
        }
    }

    private func value(forSymbol name: String, dependsOn symbol: String) -> Bool {
        var checking = [String]()
        func _value(forSymbol name: String, dependsOn symbol: String) -> Bool {
            if checking.contains(name) {
                return true
            }
            if let expression = _layoutExpressions[name] ??
                _viewControllerExpressions[name] ?? _viewExpressions[name] {
                checking.append(name)
                defer { checking.removeLast() }
                for name in expression.symbols where
                    name == symbol || _value(forSymbol: name, dependsOn: symbol) {
                    return true
                }
            }
            return false
        }
        return _value(forSymbol: name, dependsOn: symbol)
    }

    // Used by LayoutExpression and for unit tests
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

    // Note: thrown error is always a SymbolError
    private func cgFloatValue(forSymbol symbol: String) throws -> CGFloat {
        let anyValue = try value(forSymbol: symbol)
        if let cgFloatValue = anyValue as? CGFloat {
            return cgFloatValue
        }
        if let doubleValue = anyValue as? Double {
            return CGFloat(doubleValue)
        }
        if let numberValue = anyValue as? NSNumber {
            return CGFloat(numberValue)
        }
        throw SymbolError("\(symbol) is not a number", for: symbol)
    }

    // Return the best available VC for computing the layout guide
    private var _layoutGuideController: UIViewController? {
        let controller = _view.viewController
        return controller?.tabBarController?.selectedViewController ??
            controller?.navigationController?.topViewController ?? controller
    }

    // Used by LayoutExpression and for unit tests
    // Note: thrown error is always a SymbolError
    func value(forSymbol symbol: String) throws -> Any {
        try setUpExpressions()
        if let getter = _getters[symbol] {
            return try getter()
        }
        let getter: () throws -> Any
        switch symbol {
        case "left":
            getter = { [unowned self] in
                self._view.frame.minX
            }
        case "width":
            getter = { [unowned self] in
                self._view.frame.width
            }
        case "right":
            getter = { [unowned self] in
                try SymbolError.wrap({
                    try self.cgFloatValue(forSymbol: "left") + self.cgFloatValue(forSymbol: "width")
                }, for: symbol)
            }
        case "top":
            getter = { [unowned self] in
                self._view.frame.minY
            }
        case "height":
            getter = { [unowned self] in
                self._view.frame.height
            }
        case "bottom":
            getter = { [unowned self] in
                try SymbolError.wrap({
                    try self.cgFloatValue(forSymbol: "top") + self.cgFloatValue(forSymbol: "height")
                }, for: symbol)
            }
        case "topLayoutGuide.length":
            getter = { [unowned self] in
                self._layoutGuideController?.topLayoutGuide.length ?? 0
            }
        case "bottomLayoutGuide.length":
            getter = { [unowned self] in
                self._layoutGuideController?.bottomLayoutGuide.length ?? 0
            }
        case "inferredSize":
            getter = { [unowned self] in
                try self.inferSize()
            }
        case "inferredSize.width":
            getter = { [unowned self] in
                try self.inferSize().width
            }
        case "inferredSize.height":
            getter = { [unowned self] in
                try self.inferSize().height
            }
        case "inferredContentSize":
            getter = { [unowned self] in
                try self.inferContentSize()
            }
        case "inferredContentSize.width":
            getter = { [unowned self] in
                try self.inferContentSize().width
            }
        case "inferredContentSize.height":
            getter = { [unowned self] in
                try self.inferContentSize().height
            }
        case "contentInset":
            getter = { [unowned self] in
                // TODO: would prefer not to use try? for this
                // Context: not all views have a contentInset property, but we'd like to
                // be able to reference it for any view since it's used by inferContentSize()
                (try? self._view.value(forSymbol: "contentInset")) as? UIEdgeInsets ?? .zero
            }
        case "contentInset.top":
            getter = { [unowned self] in
                try (self.value(forSymbol: "contentInset") as! UIEdgeInsets).top
            }
        case "contentInset.left":
            getter = { [unowned self] in
                try (self.value(forSymbol: "contentInset") as! UIEdgeInsets).left
            }
        case "contentInset.bottom":
            getter = { [unowned self] in
                try (self.value(forSymbol: "contentInset") as! UIEdgeInsets).bottom
            }
        case "contentInset.right":
            getter = { [unowned self] in
                try (self.value(forSymbol: "contentInset") as! UIEdgeInsets).right
            }
        default:
            let head: String
            let tail: String
            if let range = symbol.range(of: ".") {
                head = symbol.substring(to: range.lowerBound)
                tail = symbol.substring(from: range.upperBound)
            } else {
                head = ""
                tail = ""
            }
            switch head {
            case "parent":
                if parent != nil {
                    getter = { [unowned self] in
                        try self.parent?.value(forSymbol: tail) as Any
                    }
                } else {
                    switch tail {
                    case "width":
                        getter = { [unowned self] in
                            self._view.superview?.bounds.width ?? self._view.frame.width
                        }
                    case "height":
                        getter = { [unowned self] in
                            self._view.superview?.bounds.height ?? self._view.frame.height
                        }
                    default:
                        getter = {
                            throw SymbolError("Undefined symbol \(tail)", for: symbol)
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
                getter = { [unowned self] in
                    try self.previous?.value(forSymbol: tail) as Any
                }
            case "next" where LayoutNode.isLayoutSymbol(tail):
                getter = { [unowned self] in
                    var next = self.next
                    while next?.isHidden == true {
                        next = next?.next
                    }
                    return try next?.value(forSymbol: tail) ?? 0
                }
            case "next":
                getter = { [unowned self] in
                    try self.next?.value(forSymbol: tail) as Any
                }
            case "strings":
                getter = { [unowned self] in
                    try self.value(forVariableOrConstant: symbol) ?? self.localizedString(forKey: tail)
                }
            default:
                getter = { [unowned self] in
                    // Try local variables/constants first, then
                    if let value = try self.value(forVariableOrConstant: symbol) {
                        return value
                    }
                    // Then controller/view symbols
                    if let viewController = self._viewController {
                        // TODO: find a better way to handle view properties
                        return try (try? viewController.value(forSymbol: symbol)) ??
                            self._view.value(forSymbol: symbol)
                    }
                    return try self._view.value(forSymbol: symbol)
                }
            }
        }
        _getters[symbol] = getter
        return try getter()
    }

    // Note: thrown error is always a SymbolError
    private func updateExpressionValues() throws {
        for (name, expression) in _viewControllerExpressions {
            let value = try expression.evaluate()
            try _viewController!.setValue(value, forExpression: name)
        }
        for (name, expression) in _viewExpressions {
            let value = try expression.evaluate()
            try _view.setValue(value, forExpression: name)
        }
        try bindActions()
    }

    // MARK: layout

    /// Is the layout's view hidden?
    public var isHidden: Bool {
        return view.isHidden
    }

    /// The anticipated frame for the view, based on the current state
    // TODO: should this be public?
    public var frame: CGRect {
        return attempt {
            CGRect(
                x: try cgFloatValue(forSymbol: "left"),
                y: try cgFloatValue(forSymbol: "top"),
                width: try cgFloatValue(forSymbol: "width"),
                height: try cgFloatValue(forSymbol: "height")
            )
        } ?? .zero
    }

    private var _widthDependsOnParent: Bool?
    private var widthDependsOnParent: Bool {
        if let result = _widthDependsOnParent {
            return result
        }
        if value(forSymbol: "width", dependsOn: "parent.width") {
            _widthDependsOnParent = true
            return true
        }
        if value(forSymbol: "width", dependsOn: "inferredSize.width"),
            expressions["contentSize"] == nil, expressions["contentSize.width"] == nil,
            !_usesAutoLayout, _view.intrinsicContentSize.width == UIViewNoIntrinsicMetric, children.isEmpty {
            _widthDependsOnParent = true
            return true
        }
        _widthDependsOnParent = false
        return false
    }

    private var _heightDependsOnParent: Bool?
    private var heightDependsOnParent: Bool {
        if let result = _heightDependsOnParent {
            return result
        }
        if value(forSymbol: "height", dependsOn: "parent.height") {
            _heightDependsOnParent = true
            return true
        }
        if value(forSymbol: "height", dependsOn: "inferredSize.height"),
            expressions["contentSize"] == nil, expressions["contentSize.height"] == nil,
            !_usesAutoLayout, _view.intrinsicContentSize.height == UIViewNoIntrinsicMetric, children.isEmpty {
            _heightDependsOnParent = true
            return true
        }
        _heightDependsOnParent = false
        return false
    }

    private func inferContentSize() throws -> CGSize {
        // Check for explicit size
        if expressions["contentSize"] != nil, !_evaluating.contains("contentSize") {
            return try value(forSymbol: "contentSize") as? CGSize ?? .zero
        }
        // TODO: remove special case
        if _view is UIStackView {
            return _view.systemLayoutSizeFitting(CGSize(
                width: try cgFloatValue(forSymbol: "width"),
                height: .greatestFiniteMagnitude
            ))
        }
        // Try best fit for subviews
        var size = CGSize.zero
        for child in children where !child.isHidden {
            if !child.widthDependsOnParent {
                var left: CGFloat = 0
                if !child.value(forSymbol: "left", dependsOn: "parent.width") {
                    left = try child.cgFloatValue(forSymbol: "left")
                }
                size.width = try max(size.width, left + child.cgFloatValue(forSymbol: "width"))
            }
            if !child.heightDependsOnParent {
                var top: CGFloat = 0
                if !child.value(forSymbol: "top", dependsOn: "parent.height") {
                    top = try child.cgFloatValue(forSymbol: "top")
                }
                size.height = try max(size.height, top + child.cgFloatValue(forSymbol: "height"))
            }
        }
        // If zero, fill superview
        let contentInset = try value(forSymbol: "contentInset") as! UIEdgeInsets
        if size.width <= 0, let width = _view.superview?.bounds.size.width {
            size.width = width - contentInset.left - contentInset.right
        }
        if size.height <= 0, let height = _view.superview?.bounds.size.height {
            size.height = height - contentInset.top - contentInset.bottom
        }
        // Check for explicit width / height
        if expressions["contentSize.width"] != nil, !_evaluating.contains("contentSize.width") {
            size.width = try cgFloatValue(forSymbol: "contentSize.width")
        } else if expressions["contentSize.height"] != nil, !_evaluating.contains("contentSize.height") {
            size.height = try cgFloatValue(forSymbol: "contentSize.height")
        }
        return size
    }

    private func computeExplicitWidth() throws -> CGFloat? {
        if !_evaluating.contains("width"),
            !_evaluating.contains("height") || !value(forSymbol: "width", dependsOn: "height") {
            return try cgFloatValue(forSymbol: "width")
        }
        if expressions["contentSize.width"] != nil, !_evaluating.contains("contentSize.width") {
            let contentInset = try value(forSymbol: "contentInset") as! UIEdgeInsets
            return try cgFloatValue(forSymbol: "contentSize.width") + contentInset.left + contentInset.right
        }
        return nil
    }

    private func computeExplicitHeight() throws -> CGFloat? {
        if !_evaluating.contains("height"),
            !_evaluating.contains("width") || !value(forSymbol: "height", dependsOn: "width") {
            return try cgFloatValue(forSymbol: "height")
        }
        if expressions["contentSize.height"] != nil, !_evaluating.contains("contentSize.height") {
            let contentInset = try value(forSymbol: "contentInset") as! UIEdgeInsets
            return try cgFloatValue(forSymbol: "contentSize.height") + contentInset.top + contentInset.bottom
        }
        return nil
    }

    private func inferSize() throws -> CGSize {
        let intrinsicSize = _view.intrinsicContentSize
        // TODO: remove special case
        if _view is UICollectionView {
            return intrinsicSize
        }
        // Try AutoLayout
        if _usesAutoLayout {
            let transform = _view.layer.transform
            _view.layer.transform = CATransform3DIdentity
            let frame = _view.frame
            let usesAutoresizing = _view.translatesAutoresizingMaskIntoConstraints
            _view.translatesAutoresizingMaskIntoConstraints = false
            if let width = try computeExplicitWidth() {
                _widthConstraint.isActive = true
                _widthConstraint.constant = width
            } else if intrinsicSize.width != UIViewNoIntrinsicMetric,
                _view.constraints.contains(where: { $0.firstAttribute == .width }) {
                _widthConstraint.isActive = true
                _widthConstraint.constant = intrinsicSize.width
            } else {
                _widthConstraint.isActive = false
            }
            if let height = try computeExplicitHeight() {
                _heightConstraint.isActive = true
                _heightConstraint.constant = height
            } else if intrinsicSize.height != UIViewNoIntrinsicMetric,
                _view.constraints.contains(where: { $0.firstAttribute == .height }) {
                _widthConstraint.isActive = true
                _widthConstraint.constant = intrinsicSize.height
            } else {
                _heightConstraint.isActive = false
            }
            _view.layoutIfNeeded()
            let size = _view.frame.size
            _widthConstraint.isActive = false
            _heightConstraint.isActive = false
            _view.translatesAutoresizingMaskIntoConstraints = usesAutoresizing
            _view.frame = frame
            _view.layer.transform = transform
            if size.width > 0 || size.height > 0 {
                return size
            }
        } else {
            _widthConstraint.isActive = false
            _heightConstraint.isActive = false
        }
        // Try intrinsic size
        var size = intrinsicSize
        if size.width != UIViewNoIntrinsicMetric || size.height != UIViewNoIntrinsicMetric {
            let explicitWidth = try computeExplicitWidth()
            if let explicitWidth = explicitWidth {
                size.width = explicitWidth
            }
            let explicitHeight = try computeExplicitHeight()
            if let explicitHeight = explicitHeight {
                size.height = explicitHeight
            }
            let fittingSize = _view.systemLayoutSizeFitting(size)
            if explicitWidth == nil, fittingSize.width > intrinsicSize.width {
                size.width = fittingSize.width
            }
            if explicitHeight == nil, fittingSize.height > intrinsicSize.height {
                size.height = fittingSize.height
            }
            return size
        }
        // Try best fit for content
        size = try inferContentSize()
        let contentInset = try value(forSymbol: "contentInset") as! UIEdgeInsets
        return CGSize(
            width: size.width + contentInset.left + contentInset.right,
            height: size.height + contentInset.top + contentInset.bottom
        )
    }

    /// The current size of the layout node's contents
    // TODO: currently this is only used by UIScrollView - should it be public?
    public var contentSize: CGSize {
        return attempt(inferContentSize) ?? .zero
    }

    // AutoLayout support
    private var _usesAutoLayout = false
    private func setUpAutoLayout() {
        _usesAutoLayout = _view.constraints.contains {
            [.top, .left, .bottom, .right, .width, .height].contains($0.firstAttribute)
        }
        setUpConstraints()
    }
    private var _widthConstraint: NSLayoutConstraint!
    private var _heightConstraint: NSLayoutConstraint!
    private func setUpConstraints() {
        if _widthConstraint != nil { return }
        _widthConstraint = _view.widthAnchor.constraint(equalToConstant: 0)
        _widthConstraint.priority = UILayoutPriorityRequired - 1
        _widthConstraint.identifier = "LayoutWidth"
        _heightConstraint = _view.heightAnchor.constraint(equalToConstant: 0)
        _heightConstraint.priority = UILayoutPriorityRequired - 1
        _heightConstraint.identifier = "LayoutHeight"
    }

    private var _suppressUpdates = false

    // Note: thrown error is always a LayoutError
    private func updateValues() throws {
        guard _suppressUpdates == false else { return }
        defer { _suppressUpdates = false }
        _suppressUpdates = true
        try LayoutError.wrap(setUpExpressions, for: self)
        clearCachedValues()
        try LayoutError.wrap(updateExpressionValues, for: self)
        for child in children {
            try LayoutError.wrap(child.updateValues, for: self)
        }
    }

    // Note: thrown error is always a LayoutError
    private func updateFrame() throws {
        guard _suppressUpdates == false else { return }
        defer { _suppressUpdates = false }
        _suppressUpdates = true
        if _view.translatesAutoresizingMaskIntoConstraints {
            let transform = _view.layer.transform
            _view.layer.transform = CATransform3DIdentity
            _view.frame = frame
            _view.layer.transform = transform
        } else {
            setUpConstraints()
            _heightConstraint.constant = frame.height
            _heightConstraint.isActive = true
            _widthConstraint.constant = frame.width
            _widthConstraint.isActive = true
        }
        for child in children {
            try LayoutError.wrap(child.updateFrame, for: self)
        }
        _view.didUpdateLayout(for: self)
        _view.viewController?.didUpdateLayout(for: self)
        try throwUnhandledError()
    }

    /// Re-evaluates all expressions for the node and its children
    /// Note: thrown error is always a LayoutError
    public func update() throws {
        try updateValues()
        try updateFrame()
    }

    // MARK: binding

    /// Mounts a node inside the specified view controller, and binds the VC as its owner
    /// Note: thrown error is always a LayoutError
    public func mount(in viewController: UIViewController) throws {
        guard parent == nil else {
            throw LayoutError.message("The mount() method should only be used on a root node.")
        }
        try bind(to: viewController)
        for controller in viewControllers {
            viewController.addChildViewController(controller)
        }
        viewController.view.addSubview(view)
        if _view.frame != viewController.view.bounds {
            _view.frame = viewController.view.bounds
            try throwUnhandledError()
        } else {
            try update()
        }
    }

    /// Mounts a node inside the specified view, and binds the view as its owner
    /// Note: thrown error is always a LayoutError
    @nonobjc public func mount(in view: UIView) throws {
        guard parent == nil else {
            throw LayoutError.message("The mount() method should only be used on a root node.")
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
        view.addSubview(_view)
        try update()
    }

    /// Unmounts and unbinds the node from its owner
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
        _view?.removeFromSuperview()
    }

    private weak var _owner: NSObject?

    /// Binds the node to the specified owner but doesn't attach the view or view controller(s)
    /// Note: thrown error is always a LayoutError
    public func bind(to owner: NSObject) throws {
        guard _owner == nil || _owner == owner || _owner == _viewController else {
            throw LayoutError("Cannot re-bind an already bound node.", for: self)
        }
        let oldDelegate = _delegate
        if oldDelegate == nil {
            _delegate = owner as? LayoutDelegate
        }
        if viewControllerClass != nil, owner != _viewController, let viewController = viewController {
            do {
                try bind(to: viewController)
                return
            } catch {
                unbind()
            }
        }
        _delegate = oldDelegate
        _owner = owner
        if _setupComplete {
            cleanUp()
        } else {
            try completeSetup()
        }
        if let outlet = outlet {
            guard let type = Swift.type(of: owner).allPropertyTypes()[outlet] else {
                throw LayoutError("`\(Swift.type(of: owner))` does not have an outlet named `\(outlet)`", for: self)
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
                    expectedType = "\(Swift.type(of: self))"
                }
            } else if type.matches(UIView.self) {
                if type.matches(view) {
                    owner.setValue(view, forKey: outlet)
                    didMatch = true
                } else {
                    expectedType = "\(viewClass)"
                }
            } else if let viewController = viewController, type.matches(UIViewController.self) {
                if type.matches(viewController) {
                    owner.setValue(viewController, forKey: outlet)
                    didMatch = true
                } else {
                    expectedType = "\(_class)"
                }
            }
            if !didMatch {
                throw LayoutError("outlet \(outlet) of \(owner.classForCoder) is not a \(expectedType)", for: self)
            }
        }
        if let type = viewExpressionTypes["delegate"], expressions["delegate"] == nil, type.matches(owner) {
            _view.setValue(owner, forKey: "delegate")
        }
        if let type = viewExpressionTypes["dataSource"], expressions["dataSource"] == nil, type.matches(owner) {
            _view.setValue(owner, forKey: "dataSource")
        }
        try bindActions()
        for child in children {
            try LayoutError.wrap({ try child.bind(to: owner) }, for: self)
        }
        try throwUnhandledError()
    }

    /// Unbinds the node from its owner but doesn't remove
    /// the view or view controller(s) from their respective parents
    public func unbind() {
        if let owner = _owner {
            if let outlet = outlet, type(of: owner).allPropertyTypes()[outlet] != nil {
                owner.setValue(nil, forKey: outlet)
            }
            if let control = view as? UIControl {
                control.unbindActions(for: owner)
            }
            _owner = nil
        }
        for child in children {
            child.unbind()
        }
        cleanUp()
    }

    private func bindActions() throws {
        guard let control = view as? UIControl, let owner = _owner else {
            return
        }
        try LayoutError.wrap({ try control.bindActions(for: owner) }, for: self)
    }
}
