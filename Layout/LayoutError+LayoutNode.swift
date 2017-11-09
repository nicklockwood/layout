//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

extension LayoutError {
    init(_ message: String, for node: LayoutNode?) {
        self.init(LayoutError.message(message), for: node)
    }

    init(_ error: Error, for node: LayoutNode?) {
        guard let node = node else {
            self.init(error)
            return
        }
        let rootURL = (node.rootURL != node.parent?.rootURL) ? node.rootURL : nil
        switch error {
        case let error as SymbolError where error.description.contains("Unknown property"):
            if error.description.contains("expression") {
                var suggestions = node.availableSymbols(forExpression: error.symbol)
                if let subError = error.error as? SymbolError {
                    suggestions = bestMatches(for: subError.symbol, in: suggestions)
                }
                self.init(LayoutError.unknownSymbol(error, suggestions), for: node)
            } else {
                let suggestions = bestMatches(for: error.symbol, in: node.availableExpressions)
                self.init(LayoutError.unknownExpression(error, suggestions), for: node)
            }
        default:
            self.init(error, in: nameOfClass(node._class), in: rootURL)
        }
    }

    static func wrap<T>(_ closure: () throws -> T, for node: LayoutNode) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error, for: node)
        }
    }
}

func bestMatches(for symbol: String, in suggestions: [String]) -> [String] {
    let matchThreshold = 3 // Minimum characters needed to count as a match
    let symbol = symbol.lowercased()
    // Find all matches containing the string
    var matches = suggestions.filter {
        let match = $0.lowercased()
        guard let range = match.range(of: symbol) else {
            return false
        }
        return match.distance(from: range.lowerBound, to: range.upperBound) >= matchThreshold
    }
    if !matches.isEmpty {
        return matches.sorted { lhs, rhs in
            let lhsMatch = lhs.lowercased()
            guard let lhsRange = lhsMatch.range(of: symbol) else {
                return false
            }
            let rhsMatch = rhs.lowercased()
            guard let rhsRange = rhsMatch.range(of: symbol) else {
                return true
            }
            let lhsDistance = lhsMatch.distance(from: lhsRange.lowerBound, to: lhsRange.upperBound)
            let rhsDistance = rhsMatch.distance(from: rhsRange.lowerBound, to: rhsRange.upperBound)
            if lhsDistance == rhsDistance {
                return lhsMatch.count < rhsMatch.count // Prefer the shortest match
            }
            return lhsDistance > rhsDistance // Prefer best match
        }
    }
    // Find all matches with a common prefix
    matches = suggestions.filter {
        $0.lowercased().commonPrefix(with: symbol).count >= matchThreshold
    }
    if !matches.isEmpty {
        // Sort suggestions by longest common prefix with symbol
        return matches.sorted { lhs, rhs in
            let lhsLength = lhs.lowercased().commonPrefix(with: symbol).count
            let rhsLength = rhs.lowercased().commonPrefix(with: symbol).count
            if lhsLength == rhsLength {
                return lhs.count < rhs.count // Prefer the shortest match
            }
            return lhsLength > rhsLength
        }
    }
    // Sort all suggestions alphabetically
    return suggestions.sorted()
}
