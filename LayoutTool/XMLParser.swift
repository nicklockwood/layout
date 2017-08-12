//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

enum XMLNode: Equatable {
    case node(
        name: String,
        attributes: [String: String],
        children: [XMLNode]
    )
    case text(String)
    case comment(String)

    var isHTML: Bool {
        guard case let .node(name, _, _) = self else {
            return false
        }
        return isHTMLElement(name)
    }

    var isEmpty: Bool {
        switch self {
        case let .node(_, _, children):
            return !children.contains {
                guard case .text = $0 else {
                    return true
                }
                return !$0.isEmpty
            }
        case let .text(text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    var isText: Bool {
        guard case .text = self else {
            return false
        }
        return true
    }

    var isComment: Bool {
        guard case .comment = self else {
            return false
        }
        return true
    }

    var children: [XMLNode] {
        if case let .node(_, _, children) = self {
            return children
        }
        return []
    }

    fileprivate mutating func append(_ node: XMLNode) {
        switch self {
        case let .node(name, attributes, children):
            self = .node(
                name: name,
                attributes: attributes,
                children: children + [node]
            )
        default:
            preconditionFailure()
        }
    }

    static func ==(lhs: XMLNode, rhs: XMLNode) -> Bool {
        switch (lhs, rhs) {
        case let (.text(lhs), .text(rhs)):
            return lhs == rhs
        case let (.comment(lhs), .comment(rhs)):
            return lhs == rhs
        default:
            // TODO: something less lazy
            return "\(lhs)" == "\(rhs)"
        }
    }
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
}

class XMLParser: NSObject, XMLParserDelegate {
    private var root: [XMLNode] = []
    private var stack: [XMLNode] = []
    private var top: XMLNode?
    private var error: FormatError?
    private var text = ""

    static func parse(data: Data) throws -> [XMLNode] {
        let parser = XMLParser()
        let foundationParser = Foundation.XMLParser(data: data)
        foundationParser.delegate = parser
        foundationParser.parse()
        if let error = parser.error {
            throw error
        }
        return parser.root
    }

    private override init() {
        super.init()
    }

    private func appendNode(_ node: XMLNode) {
        if top != nil {
            top?.append(node)
        } else {
            root.append(node)
        }
    }

    private func appendText() {
        text = text
            .replacingOccurrences(of: "\\t", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ?\\n+ ?", with: "\n", options: .regularExpression)
        if !text.isEmpty {
            appendNode(.text(text))
            text = ""
        }
    }

    // MARK: XMLParserDelegate methods

    func parser(_: Foundation.XMLParser, didStartElement elementName: String, namespaceURI _: String?, qualifiedName _: String?, attributes: [String: String] = [:]) {
        if textIsEmpty(text), top?.isEmpty == true {
            text = ""
        } else if !isHTMLElement(elementName) {
            text = text.rtrim()
        }
        appendText()
        top.map { stack.append($0) }
        let node = XMLNode.node(
            name: elementName,
            attributes: attributes,
            children: []
        )
        top = node
    }

    func parser(_: Foundation.XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?) {
        if textIsEmpty(text), top?.isEmpty == true {
            text = ""
        } else if !isHTMLElement(elementName) {
            text = text.rtrim()
        }
        appendText()
        let node = top!
        top = stack.popLast()
        appendNode(node)
    }

    func parser(_: Foundation.XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: Foundation.XMLParser, foundComment comment: String) {
        appendText()
        appendNode(.comment(comment))
    }

    func parser(_: Foundation.XMLParser, parseErrorOccurred parseError: Error) {
        guard error == nil else {
            // Don't overwrite existing error
            return
        }
        let nsError = parseError as NSError
        guard let line = nsError.userInfo["NSXMLParserErrorLineNumber"] else {
            error = .parsing("\(nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
            return
        }
        guard let message = nsError.userInfo["NSXMLParserErrorMessage"] else {
            error = .parsing("Malformed XML at line \(line)")
            return
        }
        error = .parsing("\("\(message)".trimmingCharacters(in: .whitespacesAndNewlines)) at line \(line)")
    }
}

private func isHTMLElement(_ name: String) -> Bool {
    return name.lowercased() == name
}

private func textIsEmpty(_ text: String) -> Bool {
    return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private extension String {
    func ltrim() -> String {
        var chars = unicodeScalars
        while let char = chars.first, NSCharacterSet.whitespacesAndNewlines.contains(char) {
            chars.removeFirst()
        }
        return String(chars)
    }

    func rtrim() -> String {
        var chars = unicodeScalars
        while let char = chars.last, NSCharacterSet.whitespacesAndNewlines.contains(char) {
            chars.removeLast()
        }
        return String(chars)
    }
}
