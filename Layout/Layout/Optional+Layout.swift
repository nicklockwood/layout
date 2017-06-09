//
//  Optional+Layout.swift
//  Layout
//
//  Created by Nick Lockwood on 18/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import Foundation

// Test if a value is an Optional
func isOptional(_ value: Any) -> Bool {
    return value is _Optional
}

// Unwraps an optional value or throws if nil
func unwrap(_ value: Any) throws -> Any {
    guard let optional = value as? _Optional else {
        return value
    }
    guard let value = optional.value else {
        throw LayoutError.message("Unexpected nil value")
    }
    return value
}

// Test if a value is nil
func isNil(_ value: Any) -> Bool {
    guard let optional = value as? _Optional else {
        return false
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
