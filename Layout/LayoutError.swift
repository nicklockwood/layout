//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation
import Expression

public struct SymbolError: Error, Hashable, CustomStringConvertible {
    let symbol: String
    let error: Error

    public var description: String {
        var description = String(describing: error)
        if !description.contains(symbol) {
            description = "\(description) in \(symbol)"
        }
        return description
    }

    public var hashValue: Int {
        return description.hashValue
    }

    init(_ error: Error, for symbol: String) {
        self.symbol = symbol
        if let error = error as? SymbolError, error.symbol == symbol {
            self.error = error.error
        } else {
            self.error = error
        }
    }

    init(_ message: String, for symbol: String) {
        self.init(Expression.Error.message(message), for: symbol)
    }

    static func wrap<T>(_ closure: () throws -> T, for symbol: String) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error, for: symbol)
        }
    }

    public static func ==(lhs: SymbolError, rhs: SymbolError) -> Bool {
        return lhs.symbol == rhs.symbol && lhs.description == rhs.description
    }
}

public enum LayoutError: Error, Hashable, CustomStringConvertible {
    case message(String)
    case generic(Error, AnyClass?)

    public var description: String {
        var description = ""
        switch self {
        case let .message(message):
            description = message
        case let .generic(error, viewClass):
            description = "\(error)"
            if let viewClass = viewClass {
                let className = "\(viewClass)"
                if !description.contains(className) {
                    description = "\(description) in \(className)"
                }
            }
        }
        return description
    }

    public var hashValue: Int {
        return description.hashValue
    }

    init(_ message: String, for node: LayoutNode? = nil) {
        if let node = node {
            self = LayoutError(LayoutError.message(message), for: node)
        } else {
            self = .message(message)
        }
    }

    init(_ error: Error, for viewOrControllerClass: AnyClass) {
        switch error {
        case let LayoutError.generic(error, cls) where cls === viewOrControllerClass:
            self = .generic(error, cls)
        default:
            self = .generic(error, viewOrControllerClass)
        }
    }

    init(_ error: Error, for node: LayoutNode? = nil) {
        guard let node = node else {
            switch error {
            case let LayoutError.generic(error, viewClass):
                self = .generic(error, viewClass)
            default:
                self = .generic(error, nil)
            }
            return
        }
        self = LayoutError(error, for: node.viewController.map {
            $0.classForCoder
        } ?? node.view.classForCoder)
    }

    static func wrap<T>(_ closure: () throws -> T, for node: LayoutNode) throws -> T {
        do {
            return try closure()
        } catch {
            throw self.init(error, for: node)
        }
    }

    public static func ==(lhs: LayoutError, rhs: LayoutError) -> Bool {
        return lhs.description == rhs.description
    }
}
