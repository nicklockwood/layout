//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

func format(_ files: [String]) -> [FormatError] {
    var errors = [Error]()
    for path in files {
        let url = expandPath(path)
        errors += enumerateFiles(withInputURL: url, concurrent: false) { inputURL, outputURL in
            do {
                if let xml = try parseLayoutXML(inputURL) {
                    let output = format(xml)
                    try output.write(to: outputURL, atomically: true, encoding: .utf8)
                }
                return {}
            } catch {
                return { throw error }
            }
        }
    }
    return errors.map(FormatError.init)
}

func format(_ xml: String) throws -> String {
    guard let data = xml.data(using: .utf8, allowLossyConversion: true) else {
        throw FormatError.parsing("Invalid xml string")
    }
    let xml = try XMLParser.parse(data: data)
    return format(xml)
}

func format(_ xml: [XMLNode]) -> String {
    return xml.toString(withIndent: "")
}

extension Collection where Iterator.Element == XMLNode {
    func toString(withIndent indent: String, indentFirstLine: Bool = true) -> String {
        var output = ""
        var previous: XMLNode?
        var indentNextLine = indentFirstLine
        var params = [XMLNode]()
        var nodes = Array(self)
        for (index, node) in nodes.enumerated().reversed() {
            if node.isParam {
                var i = index
                while i > 0, nodes[i - 1].isComment {
                    i -= 1
                }
                params = nodes[i ... index] + params
                nodes[i ... index] = []
            }
        }
        for node in params + nodes {
            if node.isLinebreak, previous?.isHTML != true {
                continue
            }
            if let previous = previous {
                if previous.isParam, !node.isParam, !node.isComment {
                    if !node.isHTML {
                        output += "\n"
                    }
                    output += "\n"
                } else if !(node.isText && previous.isHTML), !(node.isHTML && previous.isText) {
                    output += "\n"
                }
            }
            if output.hasSuffix("\n") {
                indentNextLine = true
            }
            switch node {
            case .text("\n"):
                continue
            case .comment:
                if let previous = previous, !previous.isComment, !previous.isLinebreak {
                    output += "\n"
                    indentNextLine = true
                }
                fallthrough
            default:
                output += node.toString(withIndent: indent, indentFirstLine: indentNextLine)
            }
            previous = node
            indentNextLine = false
        }
        if !output.hasSuffix("\n") {
            output += "\n"
        }
        return output
    }
}

// Threshold for min number of attributes to begin linewrapping
private let attributeWrap = 2

extension XMLNode {
    private func formatAttribute(key: String, value: String) -> String {
        var description = value
        switch key {
        case "top", "left", "bottom", "right", "width", "height", "color",
             _ where key.hasSuffix("Color"):
            if let expression = try? parseExpression(value) {
                description = expression.description
            }
        default:
            // We have to treat everying else as a string expression, because if we attempt
            // to format text outside of {...} as an expression, it will get messed up
            if let parts = try? parseStringExpression(value) {
                description = ""
                for part in parts {
                    switch part {
                    case let .string(string):
                        description += string
                    case let .expression(expression):
                        description += "{\(expression)}"
                    }
                }
            }
        }
        return "\(key)=\"\(description.xmlEncoded(forAttribute: true))\""
    }

    func toString(withIndent indent: String, indentFirstLine: Bool = true) -> String {
        switch self {
        case let .node(name, attributes, children):
            var xml = indentFirstLine ? indent : ""
            xml += "<\(name)"
            let attributes = attributes.sorted(by: { a, b in
                a.key < b.key // sort alphabetically
            })
            if attributes.count < attributeWrap || isHTML || isParam {
                for (key, value) in attributes {
                    xml += " \(formatAttribute(key: key, value: value))"
                }
            } else {
                for (key, value) in attributes {
                    xml += "\n\(indent)    \(formatAttribute(key: key, value: value))"
                }
            }
            if isParam {
                xml += "/>"
            } else if isEmpty {
                if attributes.count >= attributeWrap {
                    xml += "\n\(indent)"
                }
                if !isHTML || name == "br" {
                    xml += "/>"
                } else {
                    xml += "></\(name)>"
                }
            } else if children.count == 1, children[0].isComment || children[0].isText {
                xml += ">"
                if attributes.count >= attributeWrap {
                    xml += "\n\(children[0].toString(withIndent: indent + "    "))\n\(indent)"
                } else {
                    var body = children[0].toString(withIndent: indent, indentFirstLine: false)
                    if !isHTML {
                        body = body.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    xml += body
                }
                xml += "</\(name)>"
            } else {
                xml += ">\n"
                if attributes.count >= attributeWrap ||
                    children.first(where: { !$0.isLinebreak })?.isComment == true {
                    xml += "\n"
                }
                let body = children.toString(withIndent: indent + "    ")
                xml += "\(body)\(indent)</\(name)>"
            }
            return xml
        case let .text(text):
            if text == "\n" {
                return text
            }
            var body = text
                .xmlEncoded(forAttribute: false)
                .replacingOccurrences(of: "\\s*\\n\\s*", with: "\n\(indent)", options: .regularExpression)
            if body.hasSuffix("\n\(indent)") {
                body = body.substring(to: body.index(body.endIndex, offsetBy: -indent.characters.count))
            }
            if indentFirstLine {
                body = body.replacingOccurrences(of: "^\\s*", with: indent, options: .regularExpression)
            }
            return body
        case let .comment(comment):
            let body = comment
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s*\\n\\s*", with: "\n\(indent)", options: .regularExpression)
            return "\(indentFirstLine ? indent : "")<!-- \(body) -->"
        }
    }
}
