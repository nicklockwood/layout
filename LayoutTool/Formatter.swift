//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

func isLayout(_ xml: String) -> Bool {
    return xml.data(using: .utf8, allowLossyConversion: true).flatMap(isLayout) ?? false
}

func isLayout(_ xmlData: Data) -> Bool {
    let parser = LayoutParser()
    guard let xml = try? parser.parse(XMLParser(data: xmlData)) else {
        return false
    }
    return xml.isLayout
}

func format(_ files: [String]) -> [Error] {
    var errors = [Error]()
    for path in files {
        let url = expandPath(path)
        errors += enumerateFiles(withInputURL: url, concurrent: false) { inputURL, outputURL in
            do {
                let data = try Data(contentsOf: inputURL)
                let parser = LayoutParser()
                let input = try parser.parse(XMLParser(data: data))
                if input.isLayout {
                    let output = try format(data)
                    try output.write(to: outputURL, atomically: true, encoding: .utf8)
                }
                return { _ in }
            } catch {
                return {
                    throw error
                }
            }
        }
    }
    return errors
}

func format(_ xml: String) throws -> String {
    guard let data = xml.data(using: .utf8, allowLossyConversion: true) else {
        throw FormatError.parsing("Invalid xml string")
    }
    return try format(data)
}

func format(_ xmlData: Data) throws -> String {
    let parser = LayoutParser()
    let root = try parser.parse(XMLParser(data: xmlData))
    return root.toString(withIndent: "")
}

func format(_ xml: [XMLNode]) throws -> String {
    return xml.toString(withIndent: "")
}

extension Collection where Iterator.Element == XMLNode {
    var isLayout: Bool {
        for node in self {
            if node.isLayout {
                return true
            }
        }
        return false
    }

    var isHTML: Bool {
        return contains(where: { $0.isHTML })
    }

    func toString(withIndent indent: String, indentFirstLine: Bool = true) -> String {
        var output = ""
        var previous: XMLNode?
        var indentNextLine = indentFirstLine
        for node in self {
            if node == .text("\n"), previous?.isHTML != true {
                continue
            }
            if !output.hasSuffix("\n") {
                if (node.isText && previous?.isHTML == true) ||
                    (node.isHTML && previous?.isText == true) {
                    // Do nothing
                } else if previous != nil {
                    output += "\n"
                    indentNextLine = true
                }
            } else {
                indentNextLine = true
            }
            switch node {
            case .comment:
                if let previous = previous, !previous.isComment, previous != .text("\n") {
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
    var isLayout: Bool {
        switch self {
        case let .node(elementName, attributes, children):
            guard let firstChar = elementName.characters.first.map({ String($0) }),
                firstChar.uppercased() == firstChar else {
                return false
            }
            for key in attributes.keys {
                if ["top", "left", "bottom", "right", "width", "height", "backgroundColor"].contains(key) {
                    return true
                }
                if key.hasPrefix("layer.") {
                    return true
                }
            }
            return children.isLayout
        default:
            return false
        }
    }

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
        case let .node(elementName, attributes, children):
            var xml = indentFirstLine ? indent : ""
            xml += "<\(elementName)"
            let attributes = attributes.sorted(by: { a, b in
                a.key < b.key // sort alphabetically
            })
            if attributes.count < attributeWrap || isHTML {
                for (key, value) in attributes {
                    xml += " \(formatAttribute(key: key, value: value))"
                }
            } else {
                for (key, value) in attributes {
                    xml += "\n\(indent)    \(formatAttribute(key: key, value: value))"
                }
            }
            if isEmpty {
                if attributes.count >= attributeWrap {
                    xml += "\n\(indent)"
                }
                if !isHTML || elementName == "br" {
                    xml += "/>"
                } else {
                    xml += "></\(elementName)>"
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
                xml += "</\(elementName)>"
            } else {
                xml += ">\n"
                if attributes.count >= attributeWrap ||
                    children.first(where: { $0 != .text("\n") })?.isComment == true {
                    xml += "\n"
                }
                let body = children.toString(withIndent: indent + "    ")
                xml += "\(body)\(indent)</\(elementName)>"
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

extension String {
    func xmlEncoded(forAttribute: Bool) -> String {
        var output = ""
        for char in unicodeScalars {
            switch char {
            case "&":
                output.append("&amp;")
            case "<":
                output.append("&lt;")
            case ">":
                output.append("&gt;")
            case "\"" where forAttribute:
                output.append("&quot;")
            default:
                output.append(String(char))
            }
        }
        return output
    }
}
