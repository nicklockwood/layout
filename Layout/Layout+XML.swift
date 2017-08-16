//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension Layout {

    public init(xmlData: Data, relativeTo: String? = #file) throws {
        let xml: [XMLNode] = try LayoutError.wrap {
            try XMLParser.parse(data: xmlData, options: .skipComments)
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

    private init(xmlNode: XMLNode, relativeTo: String? = #file) throws {
        guard case .node(let className, var attributes, let childNodes) = xmlNode else {
            preconditionFailure()
        }
        var text = ""
        var isHTML = false
        var children = [Layout]()
        var parameters = [String: RuntimeType]()
        for node in childNodes {
            switch node {
            case let .node(_, attributes, childNodes):
                if node.isParam {
                    guard childNodes.isEmpty else {
                        throw LayoutError("<param> node should not contain children", for: NSClassFromString(className))
                    }
                    var name = ""
                    var type: RuntimeType?
                    for (key, value) in attributes {
                        switch key {
                        case "name":
                            name = value
                        case "type":
                            guard let runtimeType = RuntimeType(value) else {
                                throw LayoutError("Unknown or unsupported type `\(value)` in <param>. Try using `Any` instead",
                                    for: NSClassFromString(name))
                            }
                            type = runtimeType
                        default:
                            throw LayoutError("Unexpected attribute `\(key)` in <param>", for: NSClassFromString(className))
                        }
                    }
                    guard !name.isEmpty else {
                        throw LayoutError("<param> name is a required attribute", for: NSClassFromString(className))
                    }
                    guard type != nil else {
                        throw LayoutError("<param> type is a required attribute", for: NSClassFromString(className))
                    }
                    parameters[name] = type
                } else if isHTML {
                    text += try node.toHTML()
                } else if node.isHTML {
                    text = try text.xmlEncoded() + node.toHTML()
                    isHTML = true
                } else {
                    text = ""
                    try children.append(Layout(xmlNode: node))
                }
            case let .text(string):
                text += isHTML ? string.xmlEncoded() : string
            case .comment:
                preconditionFailure()
            }
        }

        let outlet = attributes["outlet"]
        attributes["outlet"] = nil
        let xmlPath = attributes["xml"]
        attributes["xml"] = nil
        let templatePath = attributes["template"]
        attributes["template"] = nil

        text = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if !text.isEmpty {
            attributes[isHTML ? "attributedText" : "text"] = text
            text = ""
        }

        self.init(
            className: className,
            outlet: outlet,
            expressions: attributes,
            parameters: parameters,
            children: children,
            xmlPath: xmlPath,
            templatePath: templatePath,
            relativePath: relativeTo
        )
    }
}

private let supportedHTMLTags: Set<String> = [
    "b", "i", "u", "strong", "em", "strike",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "p", "br", "sub", "sup", "center",
    "ul", "ol", "li",
]

private extension XMLNode {
    func toHTML() throws -> String {
        var text = ""
        switch self {
        case let .node(name, attributes, children):
            guard attributes.isEmpty else {
                throw LayoutError("Unsupported attribute `\(attributes.keys.first!)` for element <\(name)>.")
            }
            guard supportedHTMLTags.contains(name) else {
                throw LayoutError("Unsupported HTML element <\(name)>.")
            }
            guard name != "br" else {
                text += "<br/>"
                break
            }
            text += "<\(name)>"
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
