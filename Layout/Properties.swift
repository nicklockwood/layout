//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

public class RuntimeType: NSObject {
    public enum Kind {
        case any(Any.Type)
        case `struct`(String)
        case pointer(String)
        case `protocol`(Protocol)
        case `enum`(Any.Type, [String: Any], (Any) -> Any)
    }

    public let type: Kind

    @nonobjc public init(_ type: Any.Type) {
        switch "\(type)" {
        case "CGColor":
            self.type = .pointer("{CGColor=}")
        case "CGImage":
            self.type = .pointer("{CGImage=}")
        default:
            self.type = .any(type)
        }
    }

    @nonobjc public init(_ type: Protocol) {
        self.type = .protocol(type)
    }

    @nonobjc public init?(objCType: String) {
        guard let first = objCType.unicodeScalars.first else {
            assertionFailure("Empty objCType")
            return nil
        }
        switch first {
        case "c" where OBJC_BOOL_IS_BOOL == 0, "B":
            type = .any(Bool.self)
        case "c", "i", "s", "l", "q":
            type = .any(Int.self)
        case "C", "I", "S", "L", "Q":
            type = .any(UInt.self)
        case "f":
            type = .any(Float.self)
        case "d":
            type = .any(Double.self)
        case "*":
            type = .any(UnsafePointer<Int8>.self)
        case "@":
            if objCType.hasPrefix("@\"") {
                let range = "@\"".endIndex ..< objCType.index(before: objCType.endIndex)
                let className = objCType.substring(with: range)
                if className.hasPrefix("<") {
                    let range = "<".endIndex ..< className.index(before: className.endIndex)
                    let protocolName = className.substring(with: range)
                    if let proto = NSProtocolFromString(protocolName) {
                        type = .protocol(proto)
                        return
                    }
                } else if let cls = NSClassFromString(className) {
                    type = .any(cls)
                    return
                }
            }
            // Can't infer the object type, so ignore it
            return nil
        case "#":
            type = .any(AnyClass.self)
        case ":":
            type = .any(Selector.self)
        case "{":
            type = .struct(objCType)
        case "^" where objCType.hasPrefix("^{"):
            type = .pointer(objCType.substring(from: objCType.index(after: objCType.startIndex)))
        case "r" where objCType.hasPrefix("r^{"):
            type = .pointer(objCType.substring(from: "r^".endIndex))
        default:
            // Unsupported type
            return nil
        }
    }

    @nonobjc public init<T: RawRepresentable>(_ type: T.Type, _ values: [String: T]) {
        self.type = .enum(type, values, { ($0 as! T).rawValue })
    }

    @nonobjc public init<T: Any>(_ type: T.Type, _ values: [String: T]) {
        self.type = .enum(type, values, { $0 })
    }

    public override var description: String {
        switch type {
        case let .any(type),
             let .enum(type, _, _):
            return "\(type)"
        case let .struct(type),
             let .pointer(type):
            return type
        case let .protocol(type):
            return "\(type)"
        }
    }

    public func cast(_ value: Any) -> Any? {
        switch type {
        case let .any(subtype):
            switch subtype {
            case is NSNumber.Type:
                return value as? NSNumber
            case is CGFloat.Type:
                return value as? CGFloat ?? (value as? NSNumber).map { CGFloat($0) }
            case is Double.Type:
                return value as? Double ?? (value as? NSNumber).map { Double($0) }
            case is Float.Type:
                return value as? Float ?? (value as? NSNumber).map { Float($0) }
            case is Int.Type:
                return value as? Int ?? (value as? NSNumber).map { Int($0) }
            case is Bool.Type:
                return value as? Bool ?? (value as? NSNumber).map { Double($0) != 0 }
            case is String.Type,
                 is NSString.Type:
                return value as? String ?? "\(value)"
            case is NSAttributedString.Type:
                return value as? NSAttributedString ?? NSAttributedString(string: "\(value)")
            case let subtype as AnyClass:
                return (value as AnyObject).isKind(of: subtype) ? value : nil
            case _ where subtype == Any.self:
                return value
            default:
                guard let value = optionaValue(of: value) else {
                    return nil
                }
                return subtype == Swift.type(of: value) || "\(subtype)" == "\(Swift.type(of: value))" ? value : nil
            }
        case let .struct(type):
            if let value = value as? NSValue, String(cString: value.objCType) == type {
                return value
            }
            return nil
        case let .pointer(type):
            switch type {
            case "{CGColor=}":
                if let value = value as? UIColor {
                    return value.cgColor
                }
                if let value = optionaValue(of: value), "\(value)".hasPrefix("<CGColor") {
                    return value
                }
                return nil
            case "{CGImage=}":
                if let value = value as? UIImage {
                    return value.cgImage
                }
                if let value = optionaValue(of: value), "\(value)".hasPrefix("<CGImage") {
                    return value
                }
                return nil
            default:
                return value // No validation possible
            }
        case let .enum(type, enumValues, _):
            if let key = value as? String, let value = enumValues[key] {
                return value
            }
            if let value = value as? AnyHashable, let values = Array(enumValues.values) as? [AnyHashable] {
                return values.contains(value) ? value : nil
            }
            if type != Swift.type(of: value) {
                return nil
            }
            return value
        case let .protocol(type):
            return (value as AnyObject).conforms(to: type) ? value : nil
        }
    }

    public func matches(_ type: Any.Type) -> Bool {
        switch self.type {
        case let .any(_type):
            if let lhs = type as? AnyClass, let rhs = _type as? AnyClass {
                return rhs.isSubclass(of: lhs)
            }
            return type == _type || "\(type)" == "\(_type)"
        default:
            return false
        }
    }

    public func matches(_ value: Any) -> Bool {
        return cast(value) != nil
    }
}

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
                } else if objCType.hasPrefix("{CGRect") {
                    allProperties[name] = RuntimeType(CGRect.self)
                    allProperties["\(name).x"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).y"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).width"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).height"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).origin"] = RuntimeType(CGPoint.self)
                    allProperties["\(name).size"] = RuntimeType(CGSize.self)
                } else if objCType.hasPrefix("{UIEdgeInsets") {
                    allProperties[name] = RuntimeType(UIEdgeInsets.self)
                    allProperties["\(name).top"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).left"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).bottom"] = RuntimeType(CGFloat.self)
                    allProperties["\(name).right"] = RuntimeType(CGFloat.self)
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
                    if attribs.contains("R") {
                        // skip read-only properties
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

    // Safe version of setValue(forKeyPath:)
    // Checks that the property exists, and is settable, but doesn't validate the type
    func _setValue(_ value: Any, forKeyPath name: String) throws {
        var prevKey = name
        var prevTarget: NSObject?
        var target = self as NSObject
        let parts = name.components(separatedBy: ".")
        for key in parts.dropLast() {
            guard target.responds(to: Selector(key)) else {
                throw SymbolError("Unknown property `\(key)` of `\(type(of: target))`", for: name)
            }
            guard let nextTarget = target.value(forKey: key) as? NSObject else {
                throw SymbolError("Encountered nil value for `\(key)` of `\(type(of: target))`", for: name)
            }
            prevKey = key
            prevTarget = target
            target = nextTarget
        }
        // TODO: optimize this
        var key = parts.last!
        let characters = key.characters
        let setter = "set\(String(characters.first!).uppercased())\(String(characters.dropFirst())):"
        guard target.responds(to: Selector(setter)) else {
            if key.hasPrefix("is") {
                let characters = characters.dropFirst(2)
                let setter = "set\(String(characters)):"
                if target.responds(to: Selector(setter)) {
                    target.setValue(value, forKey: "\(String(characters.first!).lowercased())\(String(characters.dropFirst()))")
                    return
                }
            }
            var newValue: NSObject?
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
                    default:
                        break
                    }
                } else if key == "origin", value is CGPoint {
                    rect.origin = value as! CGPoint
                    newValue = rect as NSValue
                } else if key == "size", value is CGSize {
                    rect.size = value as! CGSize
                    newValue = rect as NSValue
                }
            case var insets as UIEdgeInsets:
                if value is NSNumber {
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
                }
            default:
                break
            }
            guard let value = newValue else {
                throw SymbolError("No valid setter found for property `\(key)` of `\(type(of: target))`", for: name)
            }
            guard let prevTarget = prevTarget else {
                throw SymbolError("Cannot set property `\(key)` of immutable `\(type(of: target))`", for: name)
            }
            prevTarget.setValue(value, forKey: prevKey)
            return
        }
        target.setValue(value, forKey: key)
    }

    /// Safe version of value(forKeyPath:)
    func _value(forKeyPath name: String) -> Any? {
        var value = self as NSObject
        for key in name.components(separatedBy: ".") {
            if value.responds(to: Selector(key)) == true,
                let nextValue = value.value(forKey: key) as? NSObject {
                value = nextValue
            } else {
                switch value {
                case let point as CGPoint:
                    switch key {
                    case "x":
                        return point.x
                    case "y":
                        return point.y
                    default:
                        return nil
                    }
                case let size as CGSize:
                    switch key {
                    case "width":
                        return size.width
                    case "height":
                        return size.height
                    default:
                        return nil
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
                        value = rect.origin as NSValue
                    case "size":
                        value = rect.size as NSValue
                    default:
                        return nil
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
                        return nil
                    }
                default:
                    return nil
                }
            }
        }
        return value
    }
}
