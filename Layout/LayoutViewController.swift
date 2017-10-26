//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

open class LayoutViewController: UIViewController, LayoutLoading {

    @objc open var layoutNode: LayoutNode? {
        didSet {
            if layoutNode?._viewController == self {
                // TODO: should this use case be allowed at all?
                return
            }
            if _error?.isTransient == true {
                _dismissError()
            }
            oldValue?.unmount()
            if let layoutNode = layoutNode {
                do {
                    try layoutNode.mount(in: self)
                    if _error == nil {
                        layoutDidLoad()
                    }
                } catch {
                    layoutError(LayoutError(error, for: layoutNode))
                }
            }
        }
    }

    private var _state: Any = ()
    private var _errorNode: LayoutNode?
    private var _error: LayoutError?

    open override var canBecomeFirstResponder: Bool {
        // Ensure Cmd-R shortcut works inside modal view controller
        return childViewControllers.isEmpty
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let errorNode = _errorNode {
            errorNode.performWithoutUpdate {
                errorNode.view.frame = view.bounds
            }
            errorNode.update()

            view.bringSubview(toFront: errorNode.view)
        } else if let layoutNode = layoutNode {
            layoutNode.performWithoutUpdate {
                layoutNode.view.frame = view.bounds
            }
            layoutNode.update()
        }
    }

    /// Called immediately after the layoutNode is set. Will not be called
    /// in the event of an error, or if layoutNode is set to nil
    open func layoutDidLoad() {
        // Override in subclass
    }

    @objc private func _reloadLayout() {
        // Async dispatch needed here to avoid a concurrency issue caused by
        // the attributedString HTML parser spinning its own runloop instance
        // https://github.com/schibsted/layout/issues/9
        DispatchQueue.main.async {
            print("Reloading \(type(of: self))")
            self._dismissError()
            self.reloadLayout(withCompletion: nil)
        }
    }

    @objc private func _hardReloadLayout() {
        loader.clearSourceURLs()
        _reloadLayout()
    }

    @objc private func _selectMatch(_ sender: UIButton) {
        if let error = _error, case let .multipleMatches(matches, path) = error {
            loader.setSourceURL(matches[sender.tag], for: path)
        }
        _reloadLayout()
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return _error == nil ? super.preferredStatusBarStyle : .lightContent
    }

    open func layoutError(_ error: LayoutError) {

        // Check error priority
        var error = error
        if let oldError = _error, !oldError.isTransient || error.isTransient {
            error = oldError // Don't replace the old error
        }

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
        setNeedsStatusBarAppearanceUpdate()
        let background: String
        var children: [LayoutNode]
        var message = "\(error)."
        switch error {
        case let .multipleMatches(matches, _):
            background = "#555"
            children = [
                LayoutNode(
                    view: UILabel(),
                    expressions: [
                        "width": "min(auto, 100% - 40)",
                        "left": "(100% - width) / 2",
                        "text": "{error} Please select the correct one.\n\nYour selection will be remembered for subsequent launches. Reset it with ⌥⌘R.",
                        "textColor": "white",
                        "numberOfLines": "0",
                    ]
                ),
            ]
            var commonPrefix = matches[0].path
            for match in matches {
                commonPrefix = commonPrefix.commonPrefix(with: match.path)
            }
            commonPrefix = (commonPrefix as NSString).deletingLastPathComponent
            for (i, match) in matches.enumerated() {
                children.append(
                    LayoutNode(
                        view: UIButton(),
                        expressions: [
                            "top": "previous.bottom + 20",
                            "width": "100% - 40",
                            "left": "20",
                            "title": "\(i + 1). \(match.path[commonPrefix.endIndex ..< match.path.endIndex])",
                            "contentHorizontalAlignment": "left",
                            "titleColor": "rgba(255,255,255,0.7)",
                            "touchUpInside": "_selectMatch:",
                            "tag": "\(i)",
                        ]
                    )
                )
            }
        default:
            background = "red"
            let suggestions = error.suggestions
            if suggestions.count == 1 {
                message += " Did you mean \(suggestions[0])?"
            } else if !suggestions.isEmpty {
                message += " Did you mean one of the following?"
            }
            children = [
                LayoutNode(
                    view: UILabel(),
                    expressions: [
                        "width": "min(auto, 100% - 40)",
                        "left": "(100% - width) / 2",
                        "text": "{error}",
                        "textColor": "white",
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
                        "textColor": "rgba(255,255,255,0.7)",
                    ]
                ),
            ]
            if suggestions.count > 1 {
                children.insert(
                    LayoutNode(
                        view: UILabel(),
                        expressions: [
                            "width": "min(auto, 100% - 40)",
                            "left": "(100% - width) / 2",
                            "text": suggestions.joined(separator: ", "),
                            "textColor": "rgba(255,255,255,0.7)",
                            "numberOfLines": "0",
                            "top": "previous.bottom + 20",
                        ]
                    ), at: 1
                )
                children.insert(
                    LayoutNode(
                        view: UIView(),
                        expressions: [
                            "width": "min(auto, 100% - 40)",
                            "left": "(100% - width) / 2",
                            "height": "1",
                            "top": "previous.bottom + 20",
                            "backgroundColor": "white",
                        ]
                    ), at: 2
                )
            }
        }
        _errorNode = LayoutNode(
            view: UIScrollView(),
            expressions: [
                "backgroundColor": "\(background)",
                "contentInset.top": "max(max(safeAreaInsets.top + 10, 20), 50% - contentSize.height / 2)",
                "contentInset.bottom": "20",
                "contentInset.left": "safeAreaInsets.left",
                "contentInset.right": "safeAreaInsets.right",
                "contentInsetAdjustmentBehavior": "never",
            ],
            children: [
                LayoutNode(
                    view: UIControl(),
                    constants: [
                        "error": message,
                    ],
                    expressions: [
                        "width": "100%",
                        "height": "auto",
                        "touchDown": "_reloadLayout",
                    ],
                    children: children
                ),
            ]
        )
        _errorNode!.view.alpha = 0
        try? _errorNode?.bind(to: self)
        view.addSubview(_errorNode!.view)
        _errorNode!.view.frame = view.bounds
        _errorNode!.update()
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
        setNeedsStatusBarAppearanceUpdate()
    }

    #if arch(i386) || arch(x86_64)

        // MARK: Only applicable when running in the simulator

        private let _keyCommands = [
            UIKeyCommand(input: "r", modifierFlags: .command, action: #selector(_reloadLayout)),
            UIKeyCommand(input: "r", modifierFlags: [.command, .alternate], action: #selector(_hardReloadLayout)),
        ]

        open override var keyCommands: [UIKeyCommand]? {
            return _keyCommands
        }

        private let reloadMessage = "Press ⌘R or Tap to Reload"

    #else

        private let reloadMessage = "Tap to Reload"

    #endif
}

extension LayoutViewController: LayoutDelegate {

    func layoutNode(_: LayoutNode, didDetectError error: Error) {
        guard let error = error as? LayoutError else {
            assertionFailure()
            return
        }
        // TODO: should we just get rid of the layoutError() method?
        layoutError(error)
    }

    func layoutNode(_: LayoutNode, localizedStringForKey key: String) -> String? {
        do {
            return try loader.loadLocalizedStrings()[key]
        } catch {
            layoutError(LayoutError(error))
            return nil
        }
    }
}
