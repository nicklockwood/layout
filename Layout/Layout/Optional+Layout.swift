//
//  Optional+Layout.swift
//  Layout
//
//  Created by Nick Lockwood on 18/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import Foundation

// Unwraps an optional value or throws if nil
func unwrap(_ value: Any) throws -> Any {
    guard let optional = value as? _Optional else {
        return value
    }
    guard let value = optional.value else {
        throw LayoutError.message("Unexpected null value")
    }
    return value
}

// Used to test if a value is Optional
private protocol _Optional {
    var value: Any? { get }
}

extension Optional: _Optional {
    var value: Any? { return self }
}
