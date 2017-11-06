//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

/// An error relating to a specific symbol/expression
internal struct SymbolError: Error, CustomStringConvertible {
    let symbol: String
    let error: Error
    var fatal = false

    init(_ error: Error, for symbol: String) {
        self.symbol = symbol
        if let error = error as? SymbolError {
            let description = String(describing: error.error)
            if symbol == error.symbol || description.contains(symbol) {
                self.error = error.error
            } else if description.contains(error.symbol) {
                self.error = SymbolError(description, for: error.symbol)
            } else {
                self.error = SymbolError("\(description) for \(error.symbol)", for: error.symbol)
            }
        } else {
            self.error = error
        }
    }

    /// Creates an error for the specified symbol
    init(_ message: String, for symbol: String) {
        self.init(Expression.Error.message(message), for: symbol)
    }

    /// Creates a fatal error for the specified symbol
    init(fatal message: String, for symbol: String) {
        self.init(Expression.Error.message(message), for: symbol)
        fatal = true
    }

    public var description: String {
        var description = String(describing: error)
        if !description.contains(symbol) {
            description = "\(description) in `\(symbol)` expression"
        }
        return description
    }

    /// Associates error thrown by the wrapped closure with the given symbol
    static func wrap<T>(_ closure: () throws -> T, for symbol: String) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error, for: symbol)
        }
    }
}

/// The public interface for all Layout errors
public enum LayoutError: Error, Hashable, CustomStringConvertible {
    case message(String)
    case generic(Error, AnyClass?)
    case unknownExpression(Error, AnyClass?)
    case unknownSymbol(Error, AnyClass?)
    case multipleMatches([URL], for: String)

    public init?(_ error: Error?) {
        guard let error = error else {
            return nil
        }
        self.init(error)
    }

    public init(_ message: String, for viewOrControllerClass: AnyClass? = nil) {
        if viewOrControllerClass != nil {
            self = .generic(LayoutError.message(message), viewOrControllerClass)
        } else {
            self = .message(message)
        }
    }

    public init(_ error: Error, for viewOrControllerClass: AnyClass? = nil) {
        switch error {
        case LayoutError.multipleMatches:
            // Should never be wrapped or it's hard to treat as special case
            self = error as! LayoutError
        case let LayoutError.generic(_, cls) where cls === viewOrControllerClass,
             let LayoutError.unknownExpression(_, cls) where cls === viewOrControllerClass,
             let LayoutError.unknownSymbol(_, cls) where cls === viewOrControllerClass:
            self = error as! LayoutError
        case let error as LayoutError where viewOrControllerClass == nil:
            self = error
        case LayoutError.unknownExpression:
            self = .unknownExpression(error, viewOrControllerClass)
        case LayoutError.unknownSymbol:
            self = .unknownSymbol(error, viewOrControllerClass)
        case let error as SymbolError where error.description.contains("Unknown property"):
            if error.description.contains("expression") {
                self = .unknownSymbol(error, viewOrControllerClass)
            } else {
                self = .unknownExpression(error, viewOrControllerClass)
            }
        default:
            self = .generic(error, viewOrControllerClass)
        }
    }

    #if arch(i386) || arch(x86_64)

        public var suggestions: [String] {
            let matchThreshold = 3 // Minimum characters needed to count as a match
            var suggestions = [String]()
            var symbolError: SymbolError?
            switch self {
            case let .unknownExpression(error, viewOrControllerClass):
                if let error = error as? LayoutError, case .unknownExpression = error {
                    return error.suggestions
                }
                symbolError = error as? SymbolError
                suggestions = ["left", "right", "width", "top", "bottom", "height", "outlet"]
                if let controllerClass = viewOrControllerClass as? UIViewController.Type {
                    suggestions +=
                        Array(controllerClass.expressionTypes.flatMap { $0.value.isAvailable ? $0.key : nil }) +
                        Array(UIView.expressionTypes.flatMap { $0.value.isAvailable ? $0.key : nil })
                } else if let viewClass = viewOrControllerClass as? UIView.Type {
                    suggestions += Array(viewClass.expressionTypes.flatMap { $0.value.isAvailable ? $0.key : nil })
                }
            case let .unknownSymbol(error, viewOrControllerClass):
                if let error = error as? LayoutError, case .unknownSymbol = error {
                    return error.suggestions
                }
                if let error = error as? SymbolError {
                    symbolError = error.error as? SymbolError
                    var type: RuntimeType?
                    if let controllerClass = viewOrControllerClass as? UIViewController.Type {
                        type = controllerClass.expressionTypes[error.symbol] ?? UIView.expressionTypes[error.symbol]
                    } else if let viewClass = viewOrControllerClass as? UIView.Type {
                        type = viewClass.expressionTypes[error.symbol]
                    }
                    if let subtype = type?.type {
                        switch subtype {
                        case let .enum(_, values):
                            // Suggest enum types
                            suggestions = Array(values.keys)
                        case let .options(_, values):
                            // Suggest options types
                            suggestions = Array(values.keys)
                        default:
                            break
                        }
                    }
                }
            default:
                return []
            }
            if let error = symbolError {
                let symbol = error.symbol.lowercased()
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
                            return lhsMatch.characters.count < rhsMatch.characters.count // Prefer the shortest match
                        }
                        return lhsDistance > rhsDistance // Prefer best match
                    }
                }
                // Find all matches with a common prefix
                matches = suggestions.filter {
                    $0.lowercased().commonPrefix(with: symbol).characters.count >= matchThreshold
                }
                if !matches.isEmpty {
                    // Sort suggestions by longest common prefix with symbol
                    return matches.sorted { lhs, rhs in
                        let lhsLength = lhs.lowercased().commonPrefix(with: symbol).characters.count
                        let rhsLength = rhs.lowercased().commonPrefix(with: symbol).characters.count
                        if lhsLength == rhsLength {
                            return lhs.characters.count < rhs.characters.count // Prefer the shortest match
                        }
                        return lhsLength > rhsLength
                    }
                }
                // Sort all single-element properties alphabetically
                return suggestions.filter { !$0.contains(".") }.sorted()
            }
            return suggestions
        }

    #else

        public var suggestions: [String] { return [] }

    #endif

    public var description: String {
        switch self {
        case let .message(message):
            return message
        case let .generic(error, viewClass),
             let .unknownSymbol(error, viewClass),
             let .unknownExpression(error, viewClass):
            var description = "\(error)"
            if let viewClass = viewClass {
                let className = "\(viewClass)"
                if !description.contains(className) {
                    description = "\(description) in \(className)"
                }
            }
            return description
        case let .multipleMatches(_, path):
            return "Layout found multiple source files matching \(path)"
        }
    }

    // Returns true if the error can be cleared, or false if the
    // error is fundamental, and requires a code change + reload to fix it
    public var isTransient: Bool {
        switch self {
        case let .generic(error, _),
             let .unknownSymbol(error, _),
             let .unknownExpression(error, _):
            if let error = error as? LayoutError {
                return error.isTransient
            }
            return (error as? SymbolError)?.fatal != true
        case .multipleMatches,
             _ where description.contains("XML"): // TODO: less hacky
            return false
        default:
            return true // TODO: handle expression parsing errors
        }
    }

    public var hashValue: Int {
        return description.hashValue
    }

    public static func == (lhs: LayoutError, rhs: LayoutError) -> Bool {
        return lhs.description == rhs.description
    }

    /// Converts error thrown by the wrapped closure to a LayoutError
    static func wrap<T>(_ closure: () throws -> T) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error)
        }
    }
}
