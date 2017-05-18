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
        types["textStyle"] = RuntimeType(NorthstarTextStyle.self, [
            "heading0": .heading0(.defaultColor),
            "heading1": .heading1(.defaultColor),
            "body": .body(.defaultColor),
            "bodyBold": .bodyBold(.defaultColor),
            "bodyAlt": .bodyAlt(.defaultColor),
            "bodyHint": .bodyHint(.defaultColor),
            "bodyColor": .bodyColor(.defaultColor),
            "bodyWhite": .bodyWhite(.defaultColor),
            "bodyError": .bodyColor(.colored(.northstarError)),
            "bodySoft": .bodyColor(.colored(.northstarSoft)),
            "small": .small(.defaultColor),
            "smallColor": .smallColor(.defaultColor),
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
