//
//  Northstar+Layout.swift
//  SampleApp
//
//  Created by Nick Lockwood on 27/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import Foundation
import Northstar
import Layout

extension NorthstarLabel {
    override open class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["textStyle"] = RuntimeType([
            "heading0": NorthstarTextStyle.heading0(.defaultColor),
            "heading1": NorthstarTextStyle.heading1(.defaultColor),
            "bodyError": NorthstarTextStyle.bodyColor(.colored(.northstarError)),
        ])
        return types
    }

    override open func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "textStyle":
            textStyle = value as! NorthstarTextStyle
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}
