//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

public extension LayoutNode {

    static func with(xmlData: Data, relativeTo: String? = #file) throws -> LayoutNode {
        return try LayoutParser().parse(
            XMLParser(data: xmlData),
            relativeTo: relativeTo
        )
    }

    static func with(xmlFileURL url: URL, relativeTo: String? = #file) throws -> LayoutNode? {
        return try XMLParser(contentsOf: url).map {
            try LayoutParser().parse($0, relativeTo: relativeTo)
        }
    }
}

private class LayoutParser: NSObject, XMLParserDelegate {
    private var root: LayoutNode!
    private var stack: [XMLNode] = []
    private var top: XMLNode?
    private var relativePath: String?
    private var error: LayoutError?
    private var text = ""
    private var isHTML = false
    private var parseQueue = [() -> Void]()

    private struct XMLNode {
        var elementName: String
        var attributes: [String: String]
        var children: [LayoutNode]
    }

    fileprivate func parse(_ parser: XMLParser, relativeTo: String?) throws -> LayoutNode {
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
        parseQueue.forEach { $0() }
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

    private func urlFromString(_ path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        // Check for scheme
        if path.contains(":") {
            let path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            if let url = URL(string: path) {
                return url
            }
        }

        // Assume local path
        let path = path.removingPercentEncoding ?? path
        if path.hasPrefix("~") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        } else if (path as NSString).isAbsolutePath {
            return URL(fileURLWithPath: path)
        } else {
            return Bundle.main.resourceURL?.appendingPathComponent(path)
        }
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

        let layoutNode: LayoutNode
        do {
            layoutNode = try LayoutNode(
                class: anyClass,
                outlet: outlet,
                expressions: attributes,
                children: node.children
            )
        } catch {
            self.error = LayoutError(error)
            parser.abortParsing()
            return
        }

        if let xmlPath = xmlPath, let xmlURL = urlFromString(xmlPath) {
            let loader = LayoutLoader()
            let relativePath = self.relativePath
            parseQueue.append { // Workaround for XMLParser not being re-entrant
                loader.loadLayout(
                    withContentsOfURL: xmlURL,
                    relativeTo: relativePath
                ) { node, error in
                    if let node = node {
                        do {
                            try layoutNode.update(with: node)
                        } catch {
                            layoutNode.logError(error)
                        }
                    } else if let error = error {
                        layoutNode.logError(error)
                    }
                }
            }
        }

        top = stack.popLast()
        if top != nil {
            top?.children.append(layoutNode)
        } else {
            root = layoutNode
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
