//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

/// Protocol for views or view controllers that can load and display a LayoutNode
public protocol LayoutLoading: class {
    var layoutNode: LayoutNode? { get set }
    func layoutError(_ error: LayoutError)
}

public extension LayoutLoading {

    /// Load a named Layout xml file from a local resource bundle
    func loadLayout(
        named: String? = nil,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file,
        state: Any = (),
        constants: [String: Any]...
    ) {
        assert(Thread.isMainThread)
        let name = named ?? "\(type(of: self))".components(separatedBy: ".").last!
        guard let xmlURL = bundle.url(forResource: name, withExtension: nil) ??
            bundle.url(forResource: name, withExtension: "xml") else {
            layoutError(.message("No layout XML file found for \(name)"))
            return
        }
        loadLayout(
            withContentsOfURL: xmlURL,
            relativeTo: relativeTo,
            state: state,
            constants: merge(constants),
            completion: nil
        )
    }

    /// Load a local or remote xml file via its URL
    func loadLayout(
        withContentsOfURL xmlURL: URL,
        relativeTo: String? = #file,
        state: Any = (),
        constants: [String: Any]...,
        completion: ((LayoutError?) -> Void)? = nil
    ) {
        loader.loadLayoutNode(
            withContentsOfURL: xmlURL,
            relativeTo: relativeTo,
            state: state,
            constants: merge(constants)
        ) { layoutNode, error in
            if let layoutNode = layoutNode {
                self.layoutNode = layoutNode
            }
            if let error = error {
                self.layoutError(error)
            }
            completion?(error)
        }
    }

    /// Reload the previously loaded xml file
    func reloadLayout(withCompletion completion: ((LayoutError?) -> Void)? = nil) {
        loader.reloadLayoutNode { layoutNode, error in
            if let layoutNode = layoutNode {
                self.layoutNode = layoutNode
            }
            if let error = error {
                self.layoutError(error)
            }
            completion?(error)
        }
    }

    /// Default error handler implementation - bubbles error up to the first
    /// responder that will handle it, or asserts if no handler is found
    func layoutError(_ error: LayoutError) {
        DispatchQueue.main.async {
            var responder = (self as? UIResponder)?.next
            while responder != nil {
                if let errorHandler = responder as? LayoutLoading {
                    errorHandler.layoutError(error)
                    return
                }
                responder = responder?.next ?? (responder as? UIViewController)?.parent
            }
            assertionFailure("Layout error: \(error)")
        }
    }

    // Used by LayoutViewController
    internal var loader: LayoutLoader {
        guard let loader = objc_getAssociatedObject(self, &loaderKey) as? LayoutLoader else {
            let loader = LayoutLoader()
            objc_setAssociatedObject(self, &loaderKey, loader, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return loader
        }
        return loader
    }
}

/// Default implementation of LayoutLoading for views
public extension LayoutLoading where Self: UIView {
    var layoutNode: LayoutNode? {
        get {
            return objc_getAssociatedObject(self, &layoutNodeKey) as? LayoutNode
        }
        set {
            objc_setAssociatedObject(self, &layoutNodeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            layoutNode?.unmount()
            if let layoutNode = layoutNode {
                do {
                    try layoutNode.mount(in: self)
                } catch {
                    layoutError(LayoutError(error, for: layoutNode))
                }
            }
        }
    }
}

/// Default implementation of LayoutLoading for view controllers
public extension LayoutLoading where Self: UIViewController {
    var layoutNode: LayoutNode? {
        get {
            return objc_getAssociatedObject(self, &layoutNodeKey) as? LayoutNode
        }
        set {
            objc_setAssociatedObject(self, &layoutNodeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            layoutNode?.unmount()
            if let layoutNode = layoutNode {
                do {
                    try layoutNode.mount(in: self)
                } catch {
                    layoutError(LayoutError(error, for: layoutNode))
                }
            }
        }
    }
}

// MARK: private

private var layoutNodeKey = 1
private var loaderKey = 1
