//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

open class LayoutViewController: UIViewController {

    open var layoutNode: LayoutNode? {
        didSet {
            if layoutNode?.viewController == self {
                // TODO: should this use case be allowed at all?
                return
            }
            oldValue?.unmount()
            if let layoutNode = layoutNode {
                do {
                    try layoutNode.mount(in: self)
                    _dismissError()
                    layoutDidLoad()
                } catch {
                    layoutError(LayoutError(error, for: layoutNode))
                }
            }
        }
    }

    fileprivate var _loader: LayoutLoader?
    private var _state: Any = ()
    private var _errorNode: LayoutNode?
    private var _error: LayoutError?

    private var isReloadable: Bool {
        return layoutNode != nil || _loader != nil
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

    public func loadLayout(
        named: String? = nil,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file,
        state: Any = (),
        constants: [String: Any]...) {
        assert(Thread.isMainThread)
        let name = named ?? "\(type(of: self))".components(separatedBy: ".").last!
        guard let xmlURL = bundle.url(forResource: name, withExtension: nil) ??
            bundle.url(forResource: name, withExtension: "xml") else {
            layoutError(.message("No layout XML file found for `\(name)`"))
            return
        }
        loadLayout(
            withContentsOfURL: xmlURL,
            relativeTo: relativeTo,
            state: state,
            constants: merge(constants)
        )
    }

    public func loadLayout(
        withContentsOfURL xmlURL: URL,
        relativeTo: String? = #file,
        state: Any = (),
        constants: [String: Any]...,
        completion: ((LayoutError?) -> Void)? = nil) {
        if _loader == nil {
            _loader = LayoutLoader()
        }
        _loader?.loadLayout(
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

    @objc private func _reloadLayout() {
        print("Reloading \(type(of: self))")
        reloadLayout(withCompletion: nil)
    }

    public func reloadLayout(withCompletion completion: ((LayoutError?) -> Void)? = nil) {
        if let loader = _loader {
            loader.reloadLayout { layoutNode, error in
                if let layoutNode = layoutNode {
                    self.layoutNode = layoutNode
                }
                if let error = error {
                    self.layoutError(error)
                }
                completion?(error)
            }
        } else {
            let node = layoutNode
            layoutNode?.state = _state
            layoutNode = node
            completion?(nil)
        }
    }

    open override var canBecomeFirstResponder: Bool {
        // Ensure Cmd-R shortcut works inside modal view controller
        return childViewControllers.isEmpty
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let errorNode = _errorNode {
            errorNode.view.frame = view.bounds
            view.bringSubview(toFront: errorNode.view)
        } else if let view = layoutNode?.view {
            if self.view.bounds != view.bounds {
                view.frame = self.view.bounds
            } else {
                do {
                    try layoutNode?.update()
                } catch {
                    layoutError(LayoutError(error, for: layoutNode))
                }
            }
        }
    }

    open func layoutDidLoad() {
        // Override in subclass
    }

    open func layoutError(_ error: LayoutError) {

        // If error has no changes, just re-display it
        if let errorNode = _errorNode, error == _error {
            view.bringSubview(toFront: errorNode.view)
            errorNode.view.alpha = 0.5
            UIView.animate(withDuration: 0.25) {
                errorNode.view.alpha = 1
            }
            return
        }

        // Display error
        _dismissError()
        _error = error
        _errorNode = LayoutNode(
            view: UIControl(),
            constants: [
                "error": error,
            ],
            expressions: [
                "width": "100%",
                "height": "100%",
                "backgroundColor": "#f00",
                "touchDown": "_reloadLayout",
            ],
            children: [
                LayoutNode(
                    view: UILabel(),
                    expressions: [
                        "top": "40% - (height) / 2",
                        "width": "min(auto, 100% - 40)",
                        "left": "(100% - width) / 2",
                        "text": "{error}",
                        "textColor": "#fff",
                        "numberOfLines": "0",
                    ]
                ),
                LayoutNode(
                    view: UILabel(),
                    expressions: [
                        "top": "previous.bottom + 30",
                        "width": "auto",
                        "left": "(100% - width) / 2",
                        "text": "[\(reloadMessage)]",
                        "textColor": "rgba(255,255,255,0.6)",
                        "isHidden": "\(!isReloadable)",
                    ]
                ),
            ]
        )
        _errorNode!.view.alpha = 0
        try? _errorNode!.mount(in: self)
        UIView.animate(withDuration: 0.25) {
            self._errorNode?.view.alpha = 1
        }
    }

    private func _dismissError() {
        if let errorNode = _errorNode {
            view.bringSubview(toFront: errorNode.view)
            UIView.animate(withDuration: 0.25, animations: {
                errorNode.view.alpha = 0
            }, completion: { _ in
                errorNode.unmount()
            })
            _errorNode = nil
        }
        _error = nil
    }

    #if arch(i386) || arch(x86_64)

        // MARK: Only applicable when running in the simulator

        private let _keyCommands = [
            UIKeyCommand(input: "r", modifierFlags: .command, action: #selector(_reloadLayout)),
        ]

        open override var keyCommands: [UIKeyCommand]? {
            return _keyCommands
        }

        private let reloadMessage = "Tap or Cmd-R to Reload"

    #else

        private let reloadMessage = "Tap to Reload"

    #endif
}

extension LayoutViewController: LayoutDelegate {

    open func layoutNode(_: LayoutNode, didDetectError error: Error) {
        guard let error = error as? LayoutError else {
            assertionFailure()
            return
        }
        // TODO: should we just get rid of the layoutError() method?
        layoutError(error)
    }

    open func layoutNode(_: LayoutNode, localizedStringForKey key: String) -> String? {
        return _loader?.localizedStrings[key]
    }
}
