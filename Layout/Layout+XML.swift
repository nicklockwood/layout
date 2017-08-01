//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension Layout {

    init(xmlData: Data, relativeTo: String? = #file) throws {
        self = try LayoutParser().parse(
            XMLParser(data: xmlData),
            relativeTo: relativeTo
        )
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

    private static let htmlTags: Set<String> = [
        "b", "i", "u", "strong", "em", "strike",
        "h1", "h2", "h3", "h4", "h5", "h6",
        "p", "br", "sub", "sup", "center",
        "ul", "ol", "li"
    ]
    private func isHTMLNode(_ name: String) -> Bool {
        return LayoutParser.htmlTags.contains(name)
    }

    // MARK: XMLParserDelegate methods

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI _: String?, qualifiedName _: String?, attributes: [String: String] = [:]) {

        if isHTMLNode(elementName) {
            guard top != nil else {
                error = .message("Invalid root element `<\(elementName)>` in XML. Root element must be a UIView or UIViewController.")
                parser.abortParsing()
                return
            }
            text += "<\(elementName)"
            for (key, value) in attributes {
                text += " \"\(key)\"=\"\(value)\""
            }
            text += ">"
            isHTML = true
            return
        } else if elementName.lowercased() == elementName, NSClassFromString(elementName) == nil {
            error = .message("Unsupported HTML element `<\(elementName)>`.")
            parser.abortParsing()
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
        let templatePath = attributes["template"]
        attributes["template"] = nil

        text = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if !text.isEmpty {
            attributes[isHTML ? "attributedText" : "text"] = text
            text = ""
        }

        let layout = Layout(
            className: elementName,
            outlet: outlet,
            expressions: attributes,
            children: node.children,
            xmlPath: xmlPath,
            templatePath: templatePath,
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
