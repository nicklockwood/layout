//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

func rename(_ old: String, to new: String, in files: [String]) -> [Error] {
    var errors = [Error]()
    for path in files {
        let url = expandPath(path)
        errors += enumerateFiles(withInputURL: url, concurrent: false) { inputURL, outputURL in
            do {
                let data = try Data(contentsOf: inputURL)
                let parser = LayoutParser()
                let xml = try parser.parse(XMLParser(data: data))
                if xml.isLayout {
                    let output = try format(rename(old, to: new, in: xml))
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

func rename(_ old: String, to new: String, in xml: String) throws -> String {
    guard let data = xml.data(using: .utf8, allowLossyConversion: true) else {
        throw FormatError.parsing("Invalid xml string")
    }
    let parser = LayoutParser()
    let xml = try parser.parse(XMLParser(data: data))
    return try format(rename(old, to: new, in: xml))
}

private let stringExpressions: Set<String> = [
    "id", "udid", "uuid", "guid",
    "touchDown",
    "touchDownRepeat",
    "touchDragInside",
    "touchDragOutside",
    "touchDragEnter",
    "touchDragExit",
    "touchUpInside",
    "touchUpOutside",
    "touchCancel",
    "valueChanged",
    "primaryActionTriggered",
    "editingDidBegin",
    "editingChanged",
    "editingDidEnd",
    "editingDidEndOnExit",
    "allTouchEvents",
    "allEditingEvents",
    "allEvents",
]

func rename(_ old: String, to new: String, in xml: [XMLNode]) -> [XMLNode] {
    return xml.map {
        switch $0 {
        case .comment:
            return $0
        case let .text(text):
            guard let parts = try? parseStringExpression(text) else {
                return $0
            }
            return .text(rename(old, to: new, in: parts) ?? text)
        case .node(let elementName, var attributes, let children):
            for (key, value) in attributes {
                var isString = false
                if value.contains("{") && value.contains("}") {
                    isString = true // may not actually be a string, but we can parse it as one
                } else if stringExpressions.contains(key) {
                    isString = true
                } else {
                    let lowercaseKey = key.lowercased()
                    for suffix in [
                        "title", "text", "label", "name", "identifier",
                        "key", "font", "image", "icon"
                    ] {
                        if lowercaseKey.hasSuffix(suffix) {
                            isString = true
                            break
                        }
                    }
                }
                if !isString, let expression = try? parseExpression(value) {
                    if let result = rename(old, to: new, in: expression) {
                        attributes[key] = result
                    }
                } else if let parts = try? parseStringExpression(value),
                    let result = rename(old, to: new, in: parts) {
                    attributes[key] = result
                }
            }
            return .node(
                elementName: elementName,
                attributes: attributes,
                children: rename(old, to: new, in :children)
            )
        }
    }
}

private func rename(_ old: String, to new: String, in parts: [ParsedExpressionPart]) -> String? {
    var changed = false
    let parts: [String] = parts.map {
        switch $0 {
        case let .string(text):
            return text
        case let .expression(expression):
            if let result = rename(old, to: new, in: expression) {
                changed = true
                return "{\(result)}"
            }
            return expression.description
        }
    }
    return changed ? parts.joined() : nil
}


private func rename(_ old: String, to new: String, in expression: ParsedExpression) -> String? {
    guard expression.symbols.contains(.variable(old)) else {
        return nil
    }
    return expression.description.replacingOccurrences(of: "\\b\(old)\\b", with: new, options: .regularExpression)
}
