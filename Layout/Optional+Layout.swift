//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

// Test if a value is an Optional
func isOptional(_ value: Any) -> Bool {
    return value is _Optional
}

// Unwraps a potentially optional value or throws if nil
func unwrap(_ value: Any) throws -> Any {
    guard let optional = value as? _Optional else {
        return value
    }
    guard let value = optional.value else {
        throw LayoutError.message("Unexpected nil value")
    }
    return value
}

// Unwraps a potentially optional value or returns nil
func optionalValue(of value: Any) -> Any? {
    guard let optional = value as? _Optional else {
        return value is NSNull ? nil : value
    }
    return optional.value
}

// Test if a value is nil
func isNil(_ value: Any) -> Bool {
    guard let optional = value as? _Optional else {
        return value is NSNull
    }
    return optional.isNil
}

// Used to test if a value is Optional
private protocol _Optional {
    var isNil: Bool { get }
    var value: Any? { get }
}

extension Optional: _Optional {
    fileprivate var isNil: Bool { return value == nil ? true : false }
    fileprivate var value: Any? { return self }
}

extension ImplicitlyUnwrappedOptional: _Optional {
    fileprivate var isNil: Bool { return value == nil ? true : false }
    fileprivate var value: Any? { return self }
}
