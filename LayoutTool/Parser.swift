//
//  Parser.swift
//  Layout
//
//  Created by Nick Lockwood on 29/06/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import Foundation

enum XMLNode: Equatable {
    case node(
        elementName: String,
        attributes: [String: String],
        children: [XMLNode]
    )
    case text(String)
    case comment(String)

    var isHTML: Bool {
        guard case let .node(elementName, _, _) = self else {
            return false
        }
        return isHTMLElement(elementName)
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
        case let .node(elementName, attributes, children):
            self = .node(
                elementName: elementName,
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

private func isHTMLElement(_ elementName: String) -> Bool {
    return elementName.lowercased() == elementName
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

class LayoutParser: NSObject, XMLParserDelegate {
    private var root: [XMLNode] = []
    private var stack: [XMLNode] = []
    private var top: XMLNode?
    private var error: FormatError?
    private var text = ""

    func parse(_ parser: XMLParser) throws -> [XMLNode] {
        defer {
            root = []
            top = nil
        }
        parser.delegate = self
        parser.parse()
        if let error = error {
            throw error
        }
        return root
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

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String] = [:]) {
        if textIsEmpty(text), top?.isEmpty == true {
            text = ""
        } else if !isHTMLElement(elementName) {
            text = text.rtrim()
        }
        appendText()
        top.map { stack.append($0) }
        let node = XMLNode.node(
            elementName: elementName,
            attributes: attributes,
            children: []
        )
        top = node
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
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

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundComment comment: String) {
        appendText()
        appendNode(.comment(comment))
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        guard error == nil else {
            // Don't overwrite existing error
            return
        }
        let nsError = parseError as NSError
        guard let line = nsError.userInfo["NSXMLParserErrorLineNumber"],
            let column = nsError.userInfo["NSXMLParserErrorColumn"] else {
                error = .parsing("XML validation error: " +
                    "\(nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
                return
        }
        guard let message = nsError.userInfo["NSXMLParserErrorMessage"] else {
            error = .parsing("XML validation error at \(line):\(column)")
            return
        }
        error = .parsing("XML validation error: " +
            "\("\(message)".trimmingCharacters(in: .whitespacesAndNewlines)) at \(line):\(column)")
    }
}
