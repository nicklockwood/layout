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
        case let LayoutError.generic(_, cls) where cls === viewOrControllerClass:
            self = error as! LayoutError
        case let error as LayoutError where viewOrControllerClass == nil:
            self = error
        default:
            self = .generic(error, viewOrControllerClass)
        }
    }

    public var description: String {
        switch self {
        case let .message(message):
            return message
        case let .generic(error, viewClass):
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
        case let .generic(error, _):
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

    public static func ==(lhs: LayoutError, rhs: LayoutError) -> Bool {
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
