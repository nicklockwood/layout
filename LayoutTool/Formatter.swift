//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

func format(_ files: [String]) -> [FormatError] {
    var errors = [Error]()
    for path in files {
        let url = expandPath(path)
        errors += enumerateFiles(withInputURL: url, concurrent: false) { inputURL, outputURL in
            do {
                if let xml = try parseLayoutXML(inputURL) {
                    let output = try format(xml)
                    try output.write(to: outputURL, atomically: true, encoding: .utf8)
                }
                return {}
            } catch let FormatError.parsing(error) {
                return { throw FormatError.parsing("\(error) in \(inputURL.path)") }
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
    let xml = try FormatError.wrap { try XMLParser.parse(data: data) }
    return try format(xml)
}

func format(_ xml: [XMLNode]) throws -> String {
    return try xml.toString(withIndent: "")
}

extension Collection where Iterator.Element == XMLNode {
    func toString(withIndent indent: String, indentFirstLine: Bool = true) throws -> String {
        var output = ""
        var previous: XMLNode?
        var indentNextLine = indentFirstLine
        var params = [XMLNode]()
        var nodes = Array(self)
        for (index, node) in nodes.enumerated().reversed() {
            if node.isParameter {
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
                if previous.isParameter, !node.isParameter, !node.isComment {
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
                output += try node.toString(withIndent: indent, indentFirstLine: indentNextLine)
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
    private func formatAttribute(key: String, value: String) throws -> String {
        do {
            var description = value
            if attributeIsString(key, inNode: self) ?? true {
                // We have to treat everying we aren't sure about as a string expression, because if
                // we attempt to format text outside of {...} as an expression, it will get messed up
                let parts = try parseStringExpression(value)
                for part in parts {
                    switch part {
                    case .string, .comment:
                        break
                    case let .expression(expression):
                        try validateLayoutExpression(expression)
                    }
                }
                description = parts.map { $0.description }.joined()
            } else {
                let expression = try parseExpression(value)
                try validateLayoutExpression(expression)
                description = expression.description
            }
            return "\(key)=\"\(description.xmlEncoded(forAttribute: true))\""
        } catch {
            throw FormatError.parsing("\(error) in \(key) attribute")
        }
    }

    func toString(withIndent indent: String, indentFirstLine: Bool = true) throws -> String {
        switch self {
        case let .node(name, attributes, children):
            do {
                var xml = indentFirstLine ? indent : ""
                xml += "<\(name)"
                let attributes = attributes.sorted(by: { a, b in
                    a.key < b.key // sort alphabetically
                })
                if attributes.count < attributeWrap || isParameter || isHTML {
                    for (key, value) in attributes {
                        xml += try " \(formatAttribute(key: key, value: value))"
                    }
                } else {
                    for (key, value) in attributes {
                        xml += try "\n\(indent)    \(formatAttribute(key: key, value: value))"
                    }
                }
                if isParameter {
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
                        xml += try "\n\(children[0].toString(withIndent: indent + "    "))\n\(indent)"
                    } else {
                        var body = try children[0].toString(withIndent: indent, indentFirstLine: false)
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
                    let body = try children.toString(withIndent: indent + "    ")
                    xml += "\(body)\(indent)</\(name)>"
                }
                return xml
            } catch {
                throw FormatError.parsing("\(error) in <\(name)>")
            }
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
