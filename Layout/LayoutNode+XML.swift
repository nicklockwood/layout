//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

public extension LayoutNode {

    static func with(xmlData: Data, relativeTo: String? = #file) throws -> LayoutNode {
        return try LayoutNode(layout: LayoutParser().parse(
            XMLParser(data: xmlData),
            relativeTo: relativeTo
        ))
    }

    static func with(xmlFileURL url: URL, relativeTo: String? = #file) throws -> LayoutNode? {
        return try XMLParser(contentsOf: url).map {
            try LayoutNode(layout: LayoutParser().parse($0, relativeTo: relativeTo))
        }
    }
}

private class LayoutParser: NSObject, XMLParserDelegate {
    private var root: Layout!
    private var stack: [XMLNode] = []
    private var top: XMLNode?
    private var relativePath: String?
    private var error: LayoutError?
    private var text = ""
    private var isHTML = false

    private struct XMLNode {
        var elementName: String
        var attributes: [String: String]
        var children: [Layout]
    }

    fileprivate func parse(_ parser: XMLParser, relativeTo: String?) throws -> Layout {
        assert(Thread.isMainThread)
        defer {
            root = nil
            top = nil
        }
        relativePath = relativeTo
        parser.delegate = self
        parser.parse()
        if let error = error {
            throw error
        }
        return root
    }

    private func isHTMLNode(_ name: String) -> Bool {
        return name.lowercased() == name
    }

    // MARK: XMLParserDelegate methods

    func parser(_: XMLParser, didStartElement elementName: String, namespaceURI _: String?, qualifiedName _: String?, attributes: [String: String] = [:]) {

        if top != nil, isHTMLNode(elementName) {
            text += "<\(elementName)"
            for (key, value) in attributes {
                text += " \"\(key)\"=\"\(value)\""
            }
            text += ">"
            isHTML = true
            return
        }

        top.map { stack.append($0) }
        top = XMLNode(
            elementName: elementName,
            attributes: attributes,
            children: []
        )
        text = ""
        isHTML = false
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?) {
        guard let node = top else {
            preconditionFailure()
        }

        if isHTMLNode(elementName) {
            if elementName != "br" {
                text += "</\(elementName)>"
            }
            return
        }

        var attributes = node.attributes
        let outlet = attributes["outlet"]
        attributes["outlet"] = nil
        let xmlPath = attributes["xml"]
        attributes["xml"] = nil

        text = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if !text.isEmpty {
            attributes[isHTML ? "attributedText" : "text"] = text
            text = ""
        }

        let classPrefix = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? ""
        guard let anyClass = NSClassFromString(elementName) ??
            NSClassFromString("\(classPrefix).\(elementName)") else {
            error = LayoutError.message("Unknown class `\(elementName)` in XML")
            parser.abortParsing()
            return
        }

        let layout = Layout(
            class: anyClass,
            outlet: outlet,
            constants: [:],
            expressions: attributes,
            children: node.children,
            xmlPath: xmlPath,
            relativePath: relativePath
        )

        top = stack.popLast()
        if top != nil {
            top?.children.append(layout)
        } else {
            root = layout
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: XMLParser, parseErrorOccurred parseError: Error) {
        guard error == nil else {
            // Don't overwrite existing error
            return
        }
        let nsError = parseError as NSError
        guard let line = nsError.userInfo["NSXMLParserErrorLineNumber"],
            let column = nsError.userInfo["NSXMLParserErrorColumn"] else {
            error = .message("XML validation error: " +
                "\(nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
            return
        }
        guard let message = nsError.userInfo["NSXMLParserErrorMessage"] else {
            error = .message("XML validation error at \(line):\(column)")
            return
        }
        error = .message("XML validation error: " +
            "\("\(message)".trimmingCharacters(in: .whitespacesAndNewlines)) at \(line):\(column)")
    }
}
