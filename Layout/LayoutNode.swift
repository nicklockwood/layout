//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

/// Optional delegate protocol to be implemented by a LayoutNode's owner
@objc public protocol LayoutDelegate: class {

    /// Notify that an error occured in the node tree
    @objc optional func layoutNode(_ layoutNode: LayoutNode, didDetectError error: Error)

    /// Fetch a localized string constant for a given key.
    /// These strings are assumed to be constant for the duration of the layout tree's lifecycle
    @objc optional func layoutNode(_ layoutNode: LayoutNode, localizedStringForKey key: String) -> String?
}

public class LayoutNode: NSObject {
    public var view: UIView {
        attempt(setUpExpressions)
        return _view
    }

    public private(set) var viewController: UIViewController?
    public private(set) var outlet: String?
    public private(set) var expressions: [String: String]
    public internal(set) var constants: [String: Any]
    private var _originalExpressions: [String: String]
    @objc private var _view: UIView!

    // Get the view class without side-effects of accessing view
    private(set) var viewClass: UIView.Type

    public var viewControllers: [UIViewController] {
        guard let viewController = viewController else {
            return children.flatMap { $0.viewControllers }
        }
        return [viewController]
    }

    private var _setupComplete = false
    private func completeSetup() throws {
        guard !_setupComplete else { return }
        _setupComplete = true

        if _view == nil {
            _view = try viewClass.create(with: self)
        }

        _usesAutoLayout = _view.constraints.contains {
            [.top, .left, .bottom, .right, .width, .height].contains($0.firstAttribute)
        }

        overrideExpressions()
        _ = updateVariables()
        updateObservers()

        for (index, child) in children.enumerated() {
            child.parent = self
            try child.completeSetup()
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
            _observing = true
        }
    }

    private func stopObserving() {
        if _observing {
            NotificationCenter.default.removeObserver(self)
            removeObserver(self, forKeyPath: "_view.frame")
            _observing = false
        }
    }

    public override func observeValue(
        forKeyPath _: String?,
        of _: Any?,
        change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        attempt { try update() }
    }

    @objc private func contentSizeChanged() {
        guard _setupComplete else {
            return
        }
        cleanUp()
        attempt { try update() }
    }

    convenience init(
        class: AnyClass,
        outlet: String? = nil,
        state: Any = (),
        constants: [String: Any]...,
        expressions: [String: String] = [:],
        children: [LayoutNode] = []
    ) throws {
        self.init(
            outlet: outlet,
            state: state,
            constants: merge(constants),
            expressions: expressions,
            children: children
        )

        switch `class` {
        case let viewClass as UIView.Type:
            self.viewClass = viewClass
        case let controllerClass as UIViewController.Type:
            viewController = try controllerClass.create(with: self)
            _view = viewController!.view
            viewClass = _view.classForCoder as! UIView.Type
        default:
            throw LayoutError.message("`\(`class`)` is not a subclass of UIView or UIViewController")
        }
    }

    public convenience init(
        viewController: UIViewController,
        outlet: String? = nil,
        state: Any = (),
        constants: [String: Any]...,
        expressions: [String: String] = [:],
        children: [LayoutNode] = []
    ) {
        self.init(
            view: viewController.view,
            outlet: outlet,
            state: state,
            constants: merge(constants),
            expressions: expressions,
            children: children
        )

        self.viewController = viewController
    }

    public init(
        view: UIView? = nil,
        outlet: String? = nil,
        state: Any = (),
        constants: [String: Any]...,
        expressions: [String: String] = [:],
        children: [LayoutNode] = []
    ) {
        assert(Thread.isMainThread)

        self.viewClass = view?.classForCoder as? UIView.Type ?? UIView.self
        self.outlet = outlet
        self.state = try! unwrap(state)
        self.constants = merge(constants)
        self.expressions = expressions
        self.children = children

        _originalExpressions = expressions

        super.init()

        _view = view
    }

    deinit {
        stopObserving()
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
        do {
            try setUpExpressions()
        } catch {
            errors.insert(LayoutError(error, for: self))
        }
        for name in expressions.keys {
            guard let getter = _getters[name] else {
                errors.insert(LayoutError(SymbolError("Unknown expression name `\(name)`", for: name), for: self))
                continue
            }
            do {
                _ = try getter()
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
        if let delegate = _owner as? LayoutDelegate {
            delegate.layoutNode?(self, didDetectError: error)
            if error.isTransient {
                _unhandledError = nil
            }
            return
        }
        if var responder = _owner as? UIResponder {
            // Pass error up the chain to the first VC that can handle it
            while let nextResponder = responder.next {
                if let delegate = nextResponder as? LayoutDelegate {
                    delegate.layoutNode?(self, didDetectError: error)
                    if error.isTransient {
                        _unhandledError = nil
                    }
                    return
                }
                responder = nextResponder
            }
        }
    }

    internal func logError(_ error: Error) {
        let error = LayoutError(error, for: self)
        if _unhandledError == nil || (_unhandledError?.isTransient == true && !error.isTransient) {
            _unhandledError = error
            bubbleUnhandledError()
        }
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
            if !equal, updateVariables(), _setupComplete {
                // TODO: work out which expressions are actually affected
                attempt(update)
            }
        }
    }

    private var _variables = [String: Any]()
    private func updateVariables() -> Bool {
        if let members = state as? [String: Any] {
            _variables = members
            return true
        }
        // TODO: what about nested objects?
        var equal = true
        let mirror = Mirror(reflecting: state)
        for (name, value) in mirror.children {
            if let name = name, (equal && areEqual(_variables[name] as Any, value)) == false {
                _variables[name] = value
                equal = false
            }
        }
        return !equal
    }

    // MARK: Hierarchy

    public private(set) var children: [LayoutNode]
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
        if _setupComplete {
            child.parent = self
            if let owner = _owner {
                try? child.bind(to: owner)
            }
            if let viewController = viewController {
                viewController.didInsertChildNode(child, at: index)
            } else {
                _view.didInsertChildNode(child, at: index)
            }
        }
    }

    public func replaceChild(at index: Int, with child: LayoutNode) {
        let oldChild = children[index]
        children[index] = child
        if _setupComplete {
            child.parent = self
            if let owner = _owner {
                try? child.bind(to: owner)
            }
            if let viewController = viewController {
                viewController.didInsertChildNode(child, at: index)
            } else {
                _view.didInsertChildNode(child, at: index)
            }
        }
        oldChild.removeFromParent()
    }

    public func removeFromParent() {
        if let index = parent?.children.index(where: { $0 === self }) {
            if let viewController = parent?.viewController {
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
        let className = "\(viewController?.classForCoder ?? viewClass)"
        guard className == layout.className else {
            throw LayoutError("Cannot replace \(className) with \(layout.className)", for: self)
        }

        for child in children {
            child.removeFromParent()
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
            } else if _usesAutoLayout || _view.intrinsicContentSize.width != UIViewNoIntrinsicMetric {
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
            if expressions["top"] != nil, expressions["bottom"] != nil {
                expressions["height"] = "bottom - top"
            } else if _usesAutoLayout || _view.intrinsicContentSize.height != UIViewNoIntrinsicMetric {
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
        assert(_setupComplete)
        if let error = _unhandledError, error.isTransient {
            _unhandledError = nil
        }
        _widthDependsOnParent = nil
        _heightDependsOnParent = nil
        _evaluating.removeAll()
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
            case "contentSize.width":
                expression = LayoutExpression(contentWidthExpression: string, for: self)
            case "height":
                expression = LayoutExpression(heightExpression: string, for: self)
            case "contentSize.height":
                expression = LayoutExpression(contentHeightExpression: string, for: self)
            default:
                let type: RuntimeType
                if let viewControllerType = viewControllerExpressionTypes[symbol] {
                    isViewControllerExpression = true
                    type = viewControllerType
                } else if let viewType = viewExpressionTypes[symbol] {
                    isViewExpression = true
                    type = viewType
                } else {
                    throw SymbolError("Unknown expression name `\(symbol)`", for: symbol)
                }
                if case let .any(kind) = type.type, kind is CGFloat.Type {
                    // Allow use of % in any vertical/horizontal property expression
                    let parts = symbol.components(separatedBy: ".")
                    if ["left", "right", "x", "width"].contains(parts.last!) {
                        expression = LayoutExpression(xExpression: string, for: self)
                    } else if ["top", "bottom", "y", "height"].contains(parts.last!) {
                        expression = LayoutExpression(yExpression: string, for: self)
                    } else {
                        expression = LayoutExpression(expression: string, type: type, for: self)
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
                        try viewController?.setValue(value, forExpression: symbol)
                    } else if isViewExpression {
                        try _view.setValue(value, forExpression: symbol)
                    }
                    _getters[symbol] = { value }
                } catch {
                    // Something went wrong
                    _getters[symbol] = { throw SymbolError(error, for: symbol) }
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
                                let value = self.value(forVariableOrConstant: symbol) {
                                return value
                            }
                            throw SymbolError("Circular reference for \(symbol)", for: symbol)
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
                if isViewControllerExpression {
                    _viewControllerExpressions[symbol] = expression
                } else if isViewExpression {
                    _viewExpressions[symbol] = expression
                } else {
                    _layoutExpressions[symbol] = expression
                }
                _getters[symbol] = expression.evaluate
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

    func localizedString(forKey key: String) -> String? {
        var responder = _owner as? UIResponder
        while responder != nil {
            if let delegate = responder as? LayoutDelegate,
                let string = delegate.layoutNode?(self, localizedStringForKey: key) {
                return string
            }
            responder = responder?.next
        }
        return parent?.localizedString(forKey: key)
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

    func value(forConstant name: String) -> Any? {
        guard value(forKeyPath: name, in: _variables) == nil else {
            return nil
        }
        if let value = value(forKeyPath: name, in: constants) ?? parent?.value(forConstant: name) {
            return value
        }
        if name.hasPrefix("strings.") {
            let key = name.substring(from: "strings.".endIndex)
            return localizedString(forKey: key)
        }
        return nil
    }

    private func value(forVariableOrConstant name: String) -> Any? {
        if let value = value(forKeyPath: name, in: _variables) ??
            value(forKeyPath: name, in: constants) ??
            parent?.value(forVariableOrConstant: name) {
            return value
        }
        if name.hasPrefix("strings.") {
            let key = name.substring(from: "strings.".endIndex)
            return localizedString(forKey: key)
        }
        return nil
    }

    public lazy var viewExpressionTypes: [String: RuntimeType] = {
        self.viewClass.cachedExpressionTypes
    }()

    public lazy var viewControllerExpressionTypes: [String: RuntimeType] = {
        self.viewController.map { type(of: $0).cachedExpressionTypes } ?? [:]
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
        if let expression = _layoutExpressions[name] ??
            _viewControllerExpressions[name] ?? _viewExpressions[name] {
            for name in expression.symbols where
                name == symbol || value(forSymbol: name, dependsOn: symbol) {
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

    // Note: thrown error is always a SymbolError
    func doubleValue(forConstant symbol: String) throws -> Double? {
        guard let anyValue = value(forConstant: symbol) else {
            return nil
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

    // Return the best available VC for computing the layout guide
    private var _layoutGuideController: UIViewController? {
        let controller = _view.viewController
        return controller?.tabBarController?.selectedViewController ??
            controller?.navigationController?.topViewController ?? controller
    }

    // Note: thrown error is always a SymbolError
    // TODO: numeric values may be returned as a Double, even if original type was something else
    // this was deliberate for performance reasons, but it's a bit confusing - find a better solution
    // before making this API public
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
                try self.doubleValue(forSymbol: "left") + self.doubleValue(forSymbol: "width")
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
                try self.doubleValue(forSymbol: "top") + self.doubleValue(forSymbol: "height")
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
                self._view.value(forSymbol: "contentInset") as? UIEdgeInsets ?? .zero
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
            default:
                getter = { [unowned self] in
                    // Try local variables/constants first, then
                    if let value = self.value(forVariableOrConstant: symbol) {
                        return value
                    }
                    // Then controller/view symbols
                    if let value = self.viewController?.value(forSymbol: symbol) ??
                        self._view.value(forSymbol: symbol) {
                        return value
                    }
                    throw SymbolError("\(symbol) not found", for: symbol)
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
            try viewController?.setValue(value, forExpression: name)
        }
        for (name, expression) in _viewExpressions {
            let value = try expression.evaluate()
            try _view.setValue(value, forExpression: name)
        }
        try bindActions()
    }

    // MARK: layout

    public var isHidden: Bool {
        return view.isHidden
    }

    // TODO: should this be public?
    public var frame: CGRect {
        return attempt {
            CGRect(
                x: try CGFloat(doubleValue(forSymbol: "left")),
                y: try CGFloat(doubleValue(forSymbol: "top")),
                width: try CGFloat(doubleValue(forSymbol: "width")),
                height: try CGFloat(doubleValue(forSymbol: "height"))
            )
        } ?? .zero
    }

    private var _widthDependsOnParent: Bool?
    private var widthDependsOnParent: Bool {
        if let result = _widthDependsOnParent {
            return result
        }
        if value(forSymbol: "width", dependsOn: "parent.width") ||
            value(forSymbol: "left", dependsOn: "parent.width") {
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
        if value(forSymbol: "height", dependsOn: "parent.height") ||
            value(forSymbol: "top", dependsOn: "parent.height") {
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
            return attempt { try value(forSymbol: "contentSize") as? CGSize ?? .zero } ?? .zero
        }
        // Try best fit for subviews
        var size = CGSize.zero
        for child in children where !child.isHidden {
            if !child.widthDependsOnParent {
                size.width = max(
                    size.width,
                    CGFloat(try child.doubleValue(forSymbol: "left") + child.doubleValue(forSymbol: "width"))
                )
            }
            if !child.heightDependsOnParent {
                size.height = max(
                    size.height,
                    CGFloat(try child.doubleValue(forSymbol: "top") + child.doubleValue(forSymbol: "height"))
                )
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
            size.width = try CGFloat(doubleValue(forSymbol: "contentSize.width"))
        } else if expressions["contentSize.height"] != nil, !_evaluating.contains("contentSize.height") {
            size.height = try CGFloat(doubleValue(forSymbol: "contentSize.height"))
        }
        return size
    }

    private func computeExplicitWidth() throws -> CGFloat? {
        if !_evaluating.contains("width") {
            return try CGFloat(doubleValue(forSymbol: "width"))
        }
        if expressions["contentSize.width"] != nil, !_evaluating.contains("contentSize.width") {
            let contentInset = try value(forSymbol: "contentInset") as! UIEdgeInsets
            return try CGFloat(doubleValue(forSymbol: "contentSize.width")) + contentInset.left + contentInset.right
        }
        return nil
    }

    private func computeExplicitHeight() throws -> CGFloat? {
        if !_evaluating.contains("height") {
            return try CGFloat(doubleValue(forSymbol: "height"))
        }
        if expressions["contentSize.height"] != nil, !_evaluating.contains("contentSize.height") {
            let contentInset = try value(forSymbol: "contentInset") as! UIEdgeInsets
            return try CGFloat(doubleValue(forSymbol: "contentSize.height")) + contentInset.top + contentInset.bottom
        }
        return nil
    }

    private func inferSize() throws -> CGSize {
        let intrinsicSize = _view.intrinsicContentSize
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
                _view.constraints.contains( where: {$0.firstAttribute == .width }) {
                _widthConstraint.isActive = true
                _widthConstraint.constant = intrinsicSize.width
            } else {
                _widthConstraint.isActive = false
            }
            if let height = try computeExplicitHeight() {
                _heightConstraint.isActive = true
                _heightConstraint.constant = height
            } else if intrinsicSize.height != UIViewNoIntrinsicMetric,
                _view.constraints.contains( where: {$0.firstAttribute == .height }) {
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

    // TODO: currently this is only used by UIScrollView - should it be public?
    public var contentSize: CGSize {
        return attempt { try inferContentSize() } ?? .zero
    }

    // AutoLayout support
    private var _usesAutoLayout = false
    private lazy var _widthConstraint: NSLayoutConstraint = {
        let constraint = self._view.widthAnchor.constraint(equalToConstant: 0)
        constraint.priority = UILayoutPriorityRequired - 1
        constraint.identifier = "LayoutWidth"
        return constraint
    }()

    private lazy var _heightConstraint: NSLayoutConstraint = {
        let constraint = self._view.heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = UILayoutPriorityRequired - 1
        constraint.identifier = "LayoutHeight"
        return constraint
    }()

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

    // Note: thrown error is always a LayoutError
    public func update() throws {
        try updateValues()
        try updateFrame()
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
        if _view.frame != viewController.view.bounds {
            _view.frame = viewController.view.bounds
            try throwUnhandledError()
        } else {
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
        view.addSubview(_view)
        try update()
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
        guard _owner == nil || _owner == owner || _owner == viewController else {
            throw LayoutError("Cannot re-bind an already bound node.", for: self)
        }
        if let viewController = viewController, owner != viewController {
            do {
                try bind(to: viewController)
                return
            } catch {
                unbind()
            }
        }
        if _setupComplete {
            cleanUp()
        } else {
            try completeSetup()
        }
        _owner = owner
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
                    expectedType = "\(viewController.classForCoder)"
                }
            }
            if !didMatch {
                throw LayoutError("outlet `\(outlet)` of `\(owner.classForCoder)` is not a \(expectedType)", for: self)
            }
        }
        if let type = viewExpressionTypes["delegate"],
            _view.value(forKey: "delegate") == nil, type.matches(owner) {
            _view.setValue(owner, forKey: "delegate")
        }
        if let type = viewExpressionTypes["dataSource"],
            _view.value(forKey: "dataSource") == nil, type.matches(owner) {
            _view.setValue(owner, forKey: "dataSource")
        }
        try bindActions()
        for child in children {
            try LayoutError.wrap({ try child.bind(to: owner) }, for: self)
        }
        try throwUnhandledError()
    }

    private func unbind() {
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

private func merge(_ dictionaries: [[String: Any]]) -> [String: Any] {
    var result = [String: Any]()
    for dict in dictionaries {
        for (key, value) in dict {
            result[key] = value
        }
    }
    return result
}

