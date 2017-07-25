//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

private func urlFromString(_ path: String) -> URL? {
    if let url = URL(string: path), url.scheme != nil {
        return url
    }

    // Check for scheme
    if path.contains(":") {
        let path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        if let url = URL(string: path) {
            return url
        }
    }

    // Assume local path
    let path = path.removingPercentEncoding ?? path
    if path.hasPrefix("~") {
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    } else if (path as NSString).isAbsolutePath {
        return URL(fileURLWithPath: path)
    } else {
        return Bundle.main.resourceURL?.appendingPathComponent(path)
    }
}

extension LayoutNode {

    /// Create a new LayoutNode instance from a Layout template
    convenience init(
        layout: Layout,
        outlet: String? = nil,
        state: Any = (),
        constants: [String: Any] = [:]
    ) throws {
        try self.init(
            class: layout.getClass(),
            outlet: outlet ?? layout.outlet,
            state: state,
            constants: constants,
            expressions: layout.expressions,
            children: layout.children.map {
                try LayoutNode(layout: $0)
            }
        )
        guard let xmlPath = layout.xmlPath, let xmlURL = urlFromString(xmlPath) else {
            return
        }
        var deferredError: Error?
        LayoutLoader().loadLayout(
            withContentsOfURL: xmlURL,
            relativeTo: layout.relativePath
        ) { [weak self] layout, error in
            if let layout = layout {
                do {
                    try self?.update(with: layout)
                } catch {
                    deferredError = error
                }
            } else if let error = error {
                deferredError = error
            }
        }
        // TODO: what about errors thrown by deferred load?
        if let error = deferredError {
            throw error
        }
    }
}

extension Layout {

    // Experimental - extracts a layout template from an existing node
    init(_ node: LayoutNode) {
        self.init(
            className: "\(node.viewController?.classForCoder ?? node.viewClass)",
            outlet: node.outlet,
            expressions: node._originalExpressions,
            children: node.children.map(Layout.init(_:)),
            xmlPath: nil,
            relativePath: nil
        )
    }
}
