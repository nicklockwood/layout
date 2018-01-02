//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation
import UIKit

/// Singleton for managing the Layout debug console interface
public struct LayoutConsole {
    private static var consoleView: LayoutConsoleView = LayoutConsoleView()

    /// Controls whether error console should be shown.
    /// Enabled for debug builds and disabled for release by default
    public static var isEnabled: Bool = {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }()

    /// Displays the Red Box error screen if LayoutConsole is enabled
    /// Otherwise, it prints the error to the Xcode console
    public static func showError(_ error: Error) {
        guard isEnabled else {
            print("Layout error: \(error)")
            return
        }
        DispatchQueue.main.async {
            consoleView.showError(error)
        }
    }

    /// Hides the LayoutConsole
    public static func hide() {
        consoleView.hide()
    }
}

#if arch(i386) || arch(x86_64)
    private let reloadMessage = "Press ⌘R or Tap to Reload"
#else
    private let reloadMessage = "Tap to Reload"
#endif

private class LayoutConsoleView: UIView, LayoutLoading {
    private var error: LayoutError?

    override func layoutSubviews() {
        super.layoutSubviews()
        frame = window?.bounds ?? .zero
        layoutNode?.view.frame = bounds
    }

    func layoutError(_ error: LayoutError) {
        preconditionFailure("Error in LayoutConsoleView: \(error)")
    }

    func showError(_ error: Error) {
        assert(Thread.isMainThread)

        // Don't override existing error
        guard self.error == nil else {
            return
        }
        let error = LayoutError(error)
        self.error = error

        // Install and bring to front
        let app = UIApplication.shared
        if let window = app.delegate?.window ?? app.keyWindow {
            if self.window != window {
                frame = window.bounds
                autoresizingMask = [.flexibleWidth, .flexibleHeight]
                window.addSubview(self)
            }
            window.bringSubview(toFront: self)
        }

        // Display error
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
                message += "\n\nDid you mean `\(suggestions[0])`?"
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
        alpha = 0
        layoutNode = LayoutNode(
            view: UIScrollView(),
            expressions: [
                "backgroundColor": "\(background)",
                "contentInset.top": "max(max(safeAreaInsets.top + 10, 30), 50% - contentSize.height / 2)",
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
        (layoutNode?.view as? UIScrollView).map {
            // Workaround for contentSize calculation race condition
            // TODO: Fix contentSize calculation race condition
            $0.frame.size.width = self.frame.width
            $0.contentOffset.y = -$0.contentInset.top
        }
        UIView.animate(withDuration: 0.25) {
            self.alpha = 1
        }
    }

    func hide() {
        error = nil
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
        }, completion: { _ in
            // Check a new error hasn't been shown during animation
            if self.error == nil {
                self.removeFromSuperview()
            }
        })
    }

    @objc private func _reloadLayout() {
        ReloadManager.reload(hard: false)
    }

    @objc private func _selectMatch(_ sender: UIButton) {
        if let error = self.error, case let .multipleMatches(matches, path) = error {
            loader.setSourceURL(matches[sender.tag], for: path)
        }
        ReloadManager.reload(hard: false)
    }
}
