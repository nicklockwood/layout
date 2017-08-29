//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

extension NSObject {
    private static var propertiesKey = 0

    private class func localPropertyTypes() -> [String: RuntimeType] {
        // Check for memoized props
        if let memoized = objc_getAssociatedObject(self, &propertiesKey) as? [String: RuntimeType] {
            return memoized
        }
        if "\(self)".hasPrefix("_") { // We don't want to mess with private stuff
            return [:]
        }
        var allProperties = [String: RuntimeType]()
        func addProperty(name: String, type: RuntimeType) {
            allProperties[name] = type
            switch type.type {
            case let .struct(objCType):
                if objCType.hasPrefix("{CGPoint") {
                    allProperties[name] = RuntimeType(CGPoint.self)
                    allProperties["\(name).x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).y"] = RuntimeType(CGFloat.self)
                } else if objCType.hasPrefix("{CGSize") {
                    allProperties[name] = RuntimeType(CGSize.self)
                    allProperties["\(name).width"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).height"] = RuntimeType(CGFloat.self)
                } else if objCType.hasPrefix("{CGVector") {
                    allProperties[name] = RuntimeType(CGVector.self)
                    allProperties["\(name).dx"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).dy"] = RuntimeType(CGFloat.self)
                } else if objCType.hasPrefix("{CGRect") {
                    allProperties[name] = RuntimeType(CGRect.self)
                    allProperties["\(name).x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).y"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).width"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).height"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).origin"] = RuntimeType(CGPoint.self)
                    allProperties["\(name).origin.x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).origin.y"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).size"] = RuntimeType(CGSize.self)
                    allProperties["\(name).size.width"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).size.height"] = RuntimeType(CGFloat.self)
                } else if objCType.hasPrefix("{CGAffineTransform") {
                    allProperties[name] = RuntimeType(CGAffineTransform.self)
                    allProperties["\(name).rotation"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).scale"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).scale.x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).scale.y"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).translation.x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).translation.y"] = RuntimeType(CGFloat.self)
                } else if objCType.hasPrefix("{CATransform3D") {
                    allProperties[name] = RuntimeType(CATransform3D.self)
                    allProperties["\(name).m34"] = RuntimeType(CGFloat.self) // Used for perspective
                    allProperties["\(name).rotation"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).rotation.x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).rotation.y"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).rotation.z"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).scale"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).scale.x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).scale.y"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).scale.z"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).translation.x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).translation.y"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).translation.z"] = RuntimeType(CGFloat.self)
                } else if objCType.hasPrefix("{UIEdgeInsets") {
                    allProperties[name] = RuntimeType(UIEdgeInsets.self)
                    allProperties["\(name).top"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).left"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).bottom"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).right"] = RuntimeType(CGFloat.self)
                } else if objCType.hasPrefix("{UIOffset") {
                    allProperties[name] = RuntimeType(UIOffset.self)
                    allProperties["\(name).horizontal"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).vertical"] = RuntimeType(CGFloat.self)
                }
            default:
                break
            }
        }
        // Gather properties
        var numberOfProperties: CUnsignedInt = 0
        if let properties = class_copyPropertyList(self, &numberOfProperties) {
            for i in 0 ..< Int(numberOfProperties) {
                let cprop = properties[i]
                if let cname = property_getName(cprop), let cattribs = property_getAttributes(cprop) {
                    var name = String(cString: cname)
                    guard !name.hasPrefix("_"), // We don't want to mess with private stuff
                        allProperties[name] == nil else {
                        continue
                    }
                    // Get attributes
                    let attribs = String(cString: cattribs).components(separatedBy: ",")
                    if attribs.contains("R") || attribs.contains(where: { $0.hasPrefix("S") }) {
                        // skip read-only properties, or properties with a nonstandard setter
                        continue
                    }
                    let objCType = String(attribs[0].unicodeScalars.dropFirst())
                    guard let type = RuntimeType(objCType: objCType) else {
                        continue
                    }
                    if case let .any(type) = type.type, type is Bool.Type,
                        let attrib = attribs.first(where: { $0.hasPrefix("Gis") }) {
                        name = attrib.substring(from: "G".endIndex)
                    }
                    addProperty(name: name, type: type)
                }
            }
        }
        // Gather setter methods
        var numberOfMethods: CUnsignedInt = 0
        if let methods = class_copyMethodList(self, &numberOfMethods) {
            let maxChars = 256
            let ctype = UnsafeMutablePointer<Int8>.allocate(capacity: maxChars)
            for i in 0 ..< Int(numberOfMethods) {
                let method = methods[i]
                if let selector = method_getName(method) {
                    var name = "\(selector)"
                    guard name.hasPrefix("set"), let colonRange = name.range(of: ":"),
                        colonRange.upperBound == name.endIndex, !name.hasPrefix("set_") else {
                        continue
                    }
                    name = name.substring(with: "set".endIndex ..< colonRange.lowerBound)
                    let isName = "is\(name)"
                    guard allProperties[isName] == nil else {
                        continue
                    }
                    let characters = name.unicodeScalars
                    name = (characters.first.map { String($0) } ?? "").lowercased() + String(characters.dropFirst())
                    guard allProperties[name] == nil else {
                        continue
                    }
                    method_getArgumentType(method, 2, ctype, maxChars)
                    var objCType = String(cString: ctype)
                    if objCType == "@", name.hasSuffix("olor") {
                        objCType = "@\"UIColor\"" // Workaround for runtime not knowing the type
                    }
                    guard let type = RuntimeType(objCType: objCType) else {
                        continue
                    }
                    if case let .any(type) = type.type, type is Bool.Type,
                        instancesRespond(to: Selector(isName)) {
                        name = isName
                    }
                    addProperty(name: name, type: type)
                }
            }
            ctype.deallocate(capacity: maxChars)
        }
        // Memoize properties
        objc_setAssociatedObject(self, &propertiesKey, allProperties, .OBJC_ASSOCIATION_RETAIN)
        return allProperties
    }

    class func allPropertyTypes(excluding baseClass: NSObject.Type = NSObject.self) -> [String: RuntimeType] {
        assert(isSubclass(of: baseClass))
        var allProperties = [String: RuntimeType]()
        var cls: NSObject.Type = self
        while cls !== baseClass {
            for (name, type) in cls.localPropertyTypes() where allProperties[name] == nil {
                allProperties[name] = type
            }
            cls = cls.superclass() as? NSObject.Type ?? baseClass
        }
        return allProperties
    }

    // Safe version of `setValue(forKeyPath:)`
    // Checks that the property exists, and is settable, but doesn't validate the type
    func _setValue(_ value: Any, ofType type: RuntimeType?, forKey key: String) throws {
        _ = try _setValue(value, ofType: type, forKey: key, animated: false)
    }

    // Animated version of `_setValue(_:ofType:forKey:)`
    func _setValue(_ value: Any, ofType type: RuntimeType?, forKey key: String, animated: Bool) throws -> Bool {
        if let setter = type?.setter {
            try setter(self, key, value)
            return true
        }
        var key = key
        var setter: String
        do {
            let chars = key.characters
            if key.hasPrefix("is") {
                let chars = chars.dropFirst(2)
                setter = "set\(String(chars)):"
                if responds(to: Selector(setter)) {
                    key = "\(String(chars.first!).lowercased())\(String(chars.dropFirst()))"
                } else {
                    setter = "setIs\(String(chars)):"
                }
            } else {
                setter = "set\(String(chars.first!).uppercased())\(String(chars.dropFirst())):"
            }
        }
        if animated, let type = type {
            let selector = Selector("\(setter)animated:")
            guard responds(to: selector) else {
                return false
            }
            switch type.type {
            case let .any(type):
                switch type {
                case is Double.Type:
                    let fn = unsafeBitCast(
                        class_getMethodImplementation(type(of: self), selector),
                        to: (@convention(c) (AnyObject?, Selector, Double, ObjCBool) -> Void).self
                    )
                    fn(self, selector, Double(value as! NSNumber), true)
                    return true
                case is Float.Type:
                    let fn = unsafeBitCast(
                        class_getMethodImplementation(type(of: self), selector),
                        to: (@convention(c) (AnyObject?, Selector, Float, ObjCBool) -> Void).self
                    )
                    fn(self, selector, Float(value as! NSNumber), true)
                    return true
                case is Bool.Type:
                    let fn = unsafeBitCast(
                        class_getMethodImplementation(type(of: self), selector),
                        to: (@convention(c) (AnyObject?, Selector, ObjCBool, ObjCBool) -> Void).self
                    )
                    fn(self, selector, ObjCBool(Bool(value as! NSNumber)), true)
                    return true
                case is CGPoint.Type:
                    let fn = unsafeBitCast(
                        class_getMethodImplementation(type(of: self), selector),
                        to: (@convention(c) (AnyObject?, Selector, CGPoint, ObjCBool) -> Void).self
                    )
                    fn(self, selector, value as! CGPoint, true)
                    return true
                case is AnyObject.Type:
                    let fn = unsafeBitCast(
                        class_getMethodImplementation(type(of: self), selector),
                        to: (@convention(c) (AnyObject?, Selector, AnyObject, ObjCBool) -> Void).self
                    )
                    fn(self, selector, value as AnyObject, true)
                    return true
                default:
                    break
                }
            default:
                break
            }
            print("No animated setter implementation for \(selector)")
            return false
        }
        guard responds(to: Selector(setter)) else {
            if self is NSValue {
                throw SymbolError("Cannot set property \(key) of immutable \(type(of: self))", for: key)
            }
            throw SymbolError("Unknown property \(key) of \(classForCoder)", for: key)
        }
        setValue(isNil(value) ? nil : value, forKey: key)
        return true
    }

    // Safe version of setValue(forKeyPath:)
    // Checks that the property exists, and is settable, but doesn't validate the type
    func _setValue(_ value: Any, ofType type: RuntimeType?, forKeyPath name: String) throws {
        guard let range = name.range(of: ".", options: .backwards) else {
            try _setValue(value, ofType: type, forKey: name)
            return
        }
        var prevKey = name
        var prevTarget: NSObject?
        var target = self as NSObject
        var key = name.substring(from: range.upperBound)
        for subkey in name.substring(to: range.lowerBound).components(separatedBy: ".") {
            guard target.responds(to: Selector(subkey)) else {
                if target is NSValue {
                    key = "\(subkey).\(key)"
                    break
                }
                throw SymbolError("Unknown property \(subkey) of \(type(of: target))", for: name)
            }
            guard let nextTarget = target.value(forKey: subkey) as? NSObject else {
                // We have no way to specify optional assignment, so we'll just fail silently here
                return
            }
            prevKey = subkey
            prevTarget = target
            target = nextTarget
        }
        guard target is NSValue else {
            try target._setValue(value, ofType: type, forKey: key)
            return
        }
        // TODO: optimize this
        var newValue: NSValue?
        switch target {
        case var point as CGPoint where value is NSNumber:
            switch key {
            case "x":
                point.x = CGFloat(value as! NSNumber)
                newValue = point as NSValue
            case "y":
                point.y = CGFloat(value as! NSNumber)
                newValue = point as NSValue
            default:
                break
            }
        case var size as CGSize where value is NSNumber:
            switch key {
            case "width":
                size.width = CGFloat(value as! NSNumber)
                newValue = size as NSValue
            case "height":
                size.height = CGFloat(value as! NSNumber)
                newValue = size as NSValue
            default:
                break
            }
        case var vector as CGVector where value is NSNumber:
            switch key {
            case "dx":
                vector.dx = CGFloat(value as! NSNumber)
                newValue = vector as NSValue
            case "dy":
                vector.dy = CGFloat(value as! NSNumber)
                newValue = vector as NSValue
            default:
                break
            }
        case var rect as CGRect:
            if value is NSNumber {
                switch key {
                case "x":
                    rect.origin.x = CGFloat(value as! NSNumber)
                    newValue = rect as NSValue
                case "y":
                    rect.origin.y = CGFloat(value as! NSNumber)
                    newValue = rect as NSValue
                case "width":
                    rect.size.width = CGFloat(value as! NSNumber)
                    newValue = rect as NSValue
                case "height":
                    rect.size.height = CGFloat(value as! NSNumber)
                    newValue = rect as NSValue
                case "origin.x":
                    rect.origin.x = CGFloat(value as! NSNumber)
                    newValue = rect as NSValue
                case "origin.y":
                    rect.origin.y = CGFloat(value as! NSNumber)
                    newValue = rect as NSValue
                case "size.width":
                    rect.size.width = CGFloat(value as! NSNumber)
                    newValue = rect as NSValue
                case "size.height":
                    rect.size.height = CGFloat(value as! NSNumber)
                    newValue = rect as NSValue
                default:
                    break
                }
            } else if key == "origin" {
                if let value = value as? CGPoint {
                    rect.origin = value
                    newValue = rect as NSValue
                }
            } else if key == "size" {
                if let value = value as? CGSize {
                    rect.size = value
                    newValue = rect as NSValue
                }
            }
        case is CGAffineTransform where value is NSNumber &&
            ((prevTarget is UIView && prevKey == "transform") ||
                (prevTarget is CALayer && prevKey == "affineTransform")):
            switch key {
            case "rotation", "scale", "scale.x", "scale.y", "translation.x", "translation.y":
                prevTarget!.setValue(value, forKeyPath: "layer.transform.\(key)")
                return
            default:
                break
            }
        case var transform as CATransform3D where value is NSNumber && prevTarget != nil:
            switch key {
            case "rotation", "rotation.x", "rotation.y", "rotation.z",
                 "scale", "scale.x", "scale.y", "scale.z",
                 "translation.x", "translation.y", "translation.z":
                prevTarget!.setValue(value, forKeyPath: "\(prevKey).\(key)")
                return
            case "m34": // Used for setting perspective
                transform.m34 = CGFloat(value as! NSNumber)
                newValue = transform as NSValue
            default:
                break
            }
        case var insets as UIEdgeInsets where value is NSNumber:
            switch key {
            case "top":
                insets.top = CGFloat(value as! NSNumber)
                newValue = insets as NSValue
            case "left":
                insets.left = CGFloat(value as! NSNumber)
                newValue = insets as NSValue
            case "bottom":
                insets.bottom = CGFloat(value as! NSNumber)
                newValue = insets as NSValue
            case "right":
                insets.right = CGFloat(value as! NSNumber)
                newValue = insets as NSValue
            default:
                break
            }
        case var offset as UIOffset where value is NSNumber:
            switch key {
            case "horizontal":
                offset.horizontal = CGFloat(value as! NSNumber)
                newValue = offset as NSValue
            case "vertical":
                offset.vertical = CGFloat(value as! NSNumber)
                newValue = offset as NSValue
            default:
                break
            }
        default:
            break
        }
        if let value = newValue {
            if let prevTarget = prevTarget {
                prevTarget.setValue(value, forKey: prevKey)
                return
            }
            throw SymbolError("No valid setter found for property \(key) of \(type(of: target))", for: name)
        }
        throw SymbolError("Cannot set property \(key) of immutable \(type(of: target))", for: name)
    }

    /// Safe version of value(forKey:)
    /// Checks that the property exists, and is gettable, but doesn't validate the type
    func _value(ofType type: RuntimeType?, forKey key: String) throws -> Any? {
        if let getter = type?.getter {
            return getter(self, key)
        }
        if responds(to: Selector(key)) {
            return value(forKey: key)
        }
        switch self {
        case let point as CGPoint:
            switch key {
            case "x":
                return point.x
            case "y":
                return point.y
            default:
                throw SymbolError("Unknown property \(key) of CGPoint", for: key)
            }
        case let size as CGSize:
            switch key {
            case "width":
                return size.width
            case "height":
                return size.height
            default:
                throw SymbolError("Unknown property \(key) of CGSize", for: key)
            }
        case let vector as CGVector:
            switch key {
            case "dx":
                return vector.dx
            case "dy":
                return vector.dy
            default:
                throw SymbolError("Unknown property \(key) of CGVector", for: key)
            }
        case let rect as CGRect:
            switch key {
            case "x":
                return rect.origin.x
            case "y":
                return rect.origin.y
            case "width":
                return rect.width
            case "height":
                return rect.height
            case "origin":
                return rect.origin
            case "size":
                return rect.size
            case "minX":
                return rect.minX
            case "maxX":
                return rect.maxX
            case "minY":
                return rect.minY
            case "maxY":
                return rect.maxY
            case "midX":
                return rect.midX
            case "midY":
                return rect.midY
            default:
                throw SymbolError("Unknown property \(key) of CGRect", for: key)
            }
        case is CGAffineTransform:
            throw SymbolError("Unknown property \(key) of CGAffineTransform", for: key)
        case let transform as CATransform3D:
            switch key {
            case "m34":
                return transform.m34 // Used for perspective
            default:
                throw SymbolError("Unknown property \(key) of CATransform3D", for: key)
            }
        case let insets as UIEdgeInsets:
            switch key {
            case "top":
                return insets.top
            case "left":
                return insets.left
            case "bottom":
                return insets.bottom
            case "right":
                return insets.right
            default:
                throw SymbolError("Unknown property \(key) of UIEdgeInsets", for: key)
            }
        case let offset as UIOffset:
            switch key {
            case "horizontal":
                return offset.horizontal
            case "vertical":
                return offset.vertical
            default:
                throw SymbolError("Unknown property \(key) of UIOffset", for: key)
            }
        default:
            throw SymbolError("Unknown property \(key) of \(classForCoder)", for: key)
        }
    }

    /// Safe version of value(forKeyPath:)
    /// Checks that the property exists, and is gettable, but doesn't validate the type
    func _value(ofType type: RuntimeType?, forKeyPath name: String) throws -> Any? {
        guard let range = name.range(of: ".", options: .backwards) else {
            return try _value(ofType: type, forKey: name)
        }
        var prevKey = name
        var prevTarget: NSObject?
        var target = self as NSObject
        var key = name.substring(from: range.upperBound)
        for subkey in name.substring(to: range.lowerBound).components(separatedBy: ".") {
            guard target.responds(to: Selector(subkey)) else {
                if target is NSValue {
                    key = "\(subkey).\(key)"
                    break
                }
                throw SymbolError("Unknown property \(subkey) of \(type(of: target))", for: name)
            }
            guard let nextTarget = target.value(forKey: subkey) as? NSObject else {
                return nil
            }
            prevKey = subkey
            prevTarget = target
            target = nextTarget
        }
        if let prevTarget = prevTarget {
            switch target {
            case is CGRect:
                switch key {
                case "origin.x", "origin.y", "size.width", "size.height":
                    return prevTarget.value(forKeyPath: "\(prevKey).\(key)")
                default:
                    break
                }
            case is CGAffineTransform where
                (prevTarget is UIView && prevKey == "transform") ||
                (prevTarget is CALayer && prevKey == "affineTransform"):
                switch key {
                case "rotation", "scale", "scale.x", "scale.y", "translation.x", "translation.y":
                    return prevTarget.value(forKeyPath: "layer.transform.\(key)")
                default:
                    break
                }
            case is CATransform3D:
                switch key {
                case "rotation", "rotation.x", "rotation.y", "rotation.z",
                     "scale", "scale.x", "scale.y", "scale.z",
                     "translation", "translation.x", "translation.y", "translation.z":
                    return prevTarget.value(forKeyPath: "\(prevKey).\(key)")
                default:
                    break
                }
            default:
                break
            }
        }
        return try SymbolError.wrap({ try target._value(ofType: type, forKey: key) }, for: name)
    }
}
