//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension LayoutNode {

    /// Create a new LayoutNode instance from a Layout template
    convenience init(
        layout: Layout,
        outlet: String? = nil,
        state: Any = (),
        constants: [String: Any]...
    ) throws {
        if let path = layout.templatePath {
            throw LayoutError("Cannot initialize \(layout.className) node until content for \(path) has been loaded")
        }
        let _class: AnyClass = try layout.getClass()
        var expressions = layout.expressions
        if let body = layout.body {
            guard let viewClass = _class as? UIView.Type, let bodyExpression = viewClass.bodyExpression else {
                throw LayoutError("\(layout.className) does not support inline (X)HTML content")
            }
            expressions[bodyExpression] = body
        }
        try self.init(
            class: _class,
            id: layout.id,
            outlet: outlet ?? layout.outlet,
            state: state,
            constants: merge(constants),
            expressions: expressions,
            children: layout.children.map {
                try LayoutNode(layout: $0)
            }
        )
        _parameters = layout.parameters
        _macros = layout.macros
        guard let xmlPath = layout.xmlPath else {
            return
        }
        var deferredError: Error?
        LayoutLoader().loadLayout(
            withContentsOfURL: urlFromString(xmlPath),
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
    // TODO: this isn't a lossless conversion - find a better approach
    init(_ node: LayoutNode) {
        self.init(
            className: NSStringFromClass(node._class),
            id: node.id,
            outlet: node.outlet,
            expressions: node._originalExpressions,
            parameters: node._parameters,
            macros: node._macros,
            children: node.children.map(Layout.init(_:)),
            body: nil,
            xmlPath: nil, // TODO: what if the layout is currently loading this? Race condition!
            templatePath: nil,
            relativePath: nil
        )
    }
}
