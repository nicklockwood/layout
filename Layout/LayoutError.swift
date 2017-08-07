//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

/// An error relating to a specific symbol/expression
internal struct SymbolError: Error, CustomStringConvertible {
    let symbol: String
    let error: Error

    public var description: String {
        var description = String(describing: error)
        if !description.contains(symbol) {
            description = "\(description) in expression `\(symbol)`"
        }
        return description
    }

    init(_ error: Error, for symbol: String) {
        self.symbol = symbol
        if let error = error as? SymbolError {
            let description = String(describing: error.error)
            if symbol == error.symbol || description.contains(symbol) {
                self.error = error.error
            } else if description.contains(error.symbol) {
                 self.error = SymbolError(description, for: error.symbol)
            } else {
                self.error = SymbolError("\(description) in symbol `\(error.symbol)`", for: error.symbol)
            }
        } else {
            self.error = error
        }
    }

    /// Creates an error for the specified symbol
    init(_ message: String, for symbol: String) {
        self.init(Expression.Error.message(message), for: symbol)
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

    public init(_ error: Error) {
        self = .generic(error, nil)
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
}
