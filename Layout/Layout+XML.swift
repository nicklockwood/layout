//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension Layout {

    public init(xmlData: Data, relativeTo: String? = #file) throws {
        let xml: [XMLNode]
        do {
            xml = try XMLParser.parse(data: xmlData, options: .skipComments)
        } catch {
            throw LayoutError("XML parsing error: \(error)")
        }
        guard let root = xml.first else {
            throw LayoutError("Empty XML document.")
        }
        guard !root.isHTML else {
            guard case let .node(name, _, _) = root else {
                preconditionFailure()
            }
            throw LayoutError("Invalid root element <\(name)> in XML. Root element must be a UIView or UIViewController.")
        }
        try self.init(xmlNode: root, relativeTo: relativeTo)
    }

    private init(xmlNode: XMLNode, relativeTo: String?) throws {
        guard case .node(let className, var attributes, let childNodes) = xmlNode else {
            preconditionFailure()
        }
        var body = ""
        var isHTML = false
        var children = [Layout]()
        var parameters = [String: RuntimeType]()
        var macros = [String: String]()
        for node in childNodes {
            switch node {
            case let .node(_, attributes, childNodes):
                if isHTML { // <param> is a valid html tag, so check if we're in an HTML context first
                    body += try node.toHTML()
                } else if node.isParameter {
                    guard childNodes.isEmpty else {
                        throw LayoutError("<param> node should not contain children", for: NSClassFromString(className))
                    }
                    for key in ["name", "type"] {
                        guard let value = attributes[key], !value.isEmpty else {
                            throw LayoutError("<param> \(key) is a required attribute", for: NSClassFromString(className))
                        }
                    }
                    var name = ""
                    var type: RuntimeType?
                    for (key, value) in attributes {
                        switch key {
                        case "name":
                            name = value
                        case "type":
                            guard let runtimeType = RuntimeType(value) else {
                                throw LayoutError("Unknown or unsupported type \(value) in <param>. Try using Any instead",
                                                  for: NSClassFromString(name))
                            }
                            type = runtimeType
                        default:
                            throw LayoutError("Unexpected attribute \(key) in <param>", for: NSClassFromString(className))
                        }
                    }
                    parameters[name] = type
                } else if node.isMacro {
                    guard childNodes.isEmpty else {
                        throw LayoutError("<macro> node should not contain children", for: NSClassFromString(className))
                    }
                    for key in ["name", "value"] {
                        guard let value = attributes[key], !value.isEmpty else {
                            throw LayoutError("<macro> \(key) is a required attribute", for: NSClassFromString(className))
                        }
                    }
                    var name = ""
                    var expression: String?
                    for (key, value) in attributes {
                        switch key {
                        case "name":
                            name = value
                        case "value":
                            expression = value
                        default:
                            throw LayoutError("Unexpected attribute \(key) in <macro>", for: NSClassFromString(className))
                        }
                    }
                    macros[name] = expression
                } else if node.isHTML {
                    body = try body.xmlEncoded() + node.toHTML()
                    isHTML = true
                } else {
                    body = ""
                    try children.append(Layout(xmlNode: node, relativeTo: relativeTo))
                }
            case let .text(string):
                body += isHTML ? string.xmlEncoded() : string
            case .comment:
                preconditionFailure()
            }
        }

        func parseStringAttribute(for name: String) throws -> String? {
            guard let expression = attributes[name] else {
                return nil
            }
            attributes[name] = nil
            do {
                let parts = try parseStringExpression(expression)
                if parts.count == 1 {
                    switch parts[0] {
                    case .comment:
                        return nil
                    case let .string(string):
                        return string
                    case .expression:
                        break
                    }
                } else if parts.isEmpty {
                    return nil
                }
                throw LayoutError("\(name) must be a literal value, not an expression")
            } catch {
                throw LayoutError("\(error)", for: NSClassFromString(className))
            }
        }

        let id = try parseStringAttribute(for: "id")
        let outlet = try parseStringAttribute(for: "outlet")
        let xmlPath = try parseStringAttribute(for: "xml")
        let templatePath = try parseStringAttribute(for: "template")

        body = body
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        self.init(
            className: className,
            id: id,
            outlet: outlet,
            expressions: attributes,
            parameters: parameters,
            macros: macros,
            children: children,
            body: body.isEmpty ? nil : body,
            xmlPath: xmlPath,
            templatePath: templatePath,
            relativePath: relativeTo
        )
    }
}

// http://w3c.github.io/html/syntax.html#void-elements
private let emptyHTMLTags: Set<String> = [
    "area", "base", "br", "col", "embed", "hr",
    "img", "input", "link", "meta", "param",
    "source", "track", "wbr",
]

private extension XMLNode {
    func toHTML() throws -> String {
        var text = ""
        switch self {
        case let .node(name, attributes, children):
            guard isHTML else {
                throw LayoutError("Unsupported HTML element <\(name)>.")
            }
            text += "<\(name)"
            for (key, value) in attributes {
                text += " \(key)=\"\(value.xmlEncoded(forAttribute: true))\""
            }
            if emptyHTMLTags.contains(name) {
                // TODO: if there are children, should this be an error
                text += "/>" // TODO: should we remove the closing slash here?
                break
            }
            text += ">"
            for node in children {
                text += try node.toHTML()
            }
            return text + "</\(name)>"
        case let .text(string):
            text += string.xmlEncoded()
        case .comment:
            break // Ignore
        }
        return text
    }
}
