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

    var isLayout: Bool {
        switch self {
        case let .node(name, attributes, children):
            guard let firstChar = name.characters.first.map({ String($0) }),
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

    public var isHTML: Bool {
        guard case let .node(name, _, _) = self else {
            return false
        }
        return isHTMLElement(name)
    }

    func toHTML() throws -> String {
        var text = ""
        switch self {
        case let .node(name, attributes, children):
            guard name != "br" else {
                text += "<br/>"
                break
            }
            guard isHTMLElement(name), htmlTags.contains(name) else {
                throw XMLParser.Error("Unsupported HTML element <\(name)>.")
            }
            text += "<\(name)"
            for (key, value) in attributes {
                text += " \"\(key)\"=\"\(value)\""
            }
            text += ">"
            for node in children {
                text += try node.toHTML()
            }
            return "\(text)</\(name)>"
        case let .text(string):
            text += string // TODO: encode
        case .comment:
            break // Ignore
        }
        return text
    }

    public var isEmpty: Bool {
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

    public var isText: Bool {
        guard case .text = self else {
            return false
        }
        return true
    }

    public var isComment: Bool {
        guard case .comment = self else {
            return false
        }
        return true
    }

    public var children: [XMLNode] {
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

    public static func ==(lhs: XMLNode, rhs: XMLNode) -> Bool {
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
    private var options: Options = []
    private var root: [XMLNode] = []
    private var stack: [XMLNode] = []
    private var top: XMLNode?
    private var error: Error?
    private var text = ""

    public struct Error: Swift.Error, CustomStringConvertible {
        public let description: String

        fileprivate init(_ message: String) {
            description = message
        }

        fileprivate init(_ error: Swift.Error) {
            let nsError = error as NSError
            guard let line = nsError.userInfo["NSXMLParserErrorLineNumber"] else {
                self.init("\(nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
                return
            }
            guard let message = nsError.userInfo["NSXMLParserErrorMessage"] else {
                self.init("Malformed XML at line \(line)")
                return
            }
            self.init("\("\(message)".trimmingCharacters(in: .whitespacesAndNewlines)) at line \(line)")
        }
    }

    public struct Options: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let skipComments = Options(rawValue: 1 << 0)
    }

    public static func parse(data: Data, options: Options = []) throws -> [XMLNode] {
        let parser = XMLParser(options: options)
        let foundationParser = Foundation.XMLParser(data: data)
        foundationParser.delegate = parser
        foundationParser.parse()
        if let error = parser.error {
            throw error
        }
        return parser.root
    }

    private init(options: Options) {
        self.options = options
        super.init()
    }

    private override init() {
        preconditionFailure()
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
        if !options.contains(.skipComments) {
            appendNode(.comment(comment))
        }
    }

    func parser(_: Foundation.XMLParser, parseErrorOccurred parseError: Swift.Error) {
        guard error == nil else {
            // Don't overwrite existing error
            return
        }
        error = Error(parseError)
    }
}

private let htmlTags: Set<String> = [
    "b", "i", "u", "strong", "em", "strike",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "p", "br", "sub", "sup", "center",
    "ul", "ol", "li",
]

private func isHTMLElement(_ name: String) -> Bool {
    return name.lowercased() == name
}

private func textIsEmpty(_ text: String) -> Bool {
    return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private extension String {
    func rtrim() -> String {
        var chars = unicodeScalars
        while let char = chars.last, NSCharacterSet.whitespacesAndNewlines.contains(char) {
            chars.removeLast()
        }
        return String(chars)
    }
}
