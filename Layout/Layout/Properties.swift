//
//  PropertyObserver.swift
//  Layout
//
//  Created by Nick Lockwood on 30/03/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import Foundation

public class RuntimeType: NSObject {
    public enum Kind {
        case any(Any.Type)
        case `protocol`(Protocol)
        case `enum`(Any.Type, [String: Any], (Any) -> Any)
    }

    public let type: Kind

    @nonobjc public init(_ type: Any.Type) {
        self.type = .any(type)
    }

    @nonobjc public init(_ type: Protocol) {
        self.type = .protocol(type)
    }

    @nonobjc public init<T: RawRepresentable>(_ type: T.Type, _ values: [String: T]) {
        self.type = .enum(type, values, { return ($0 as! T).rawValue })
    }

    @nonobjc public init<T: Any>(_ type: T.Type, _ values: [String: T]) {
        self.type = .enum(type, values, { $0 })
    }

    override public var description: String {
        switch type {
        case let .any(type),
             let .enum(type, _, _):
            return "\(type)"
        case let .protocol(type):
            return "\(type)"
        }
    }

    public func cast(_ value: Any) -> Any? {
        switch type {
        case let .any(subtype):
            switch subtype {
            case _ where "\(subtype)" == "\(CGColor.self)":
                // Workaround for odd behavior in type matching
                return (value as? UIColor).map({ $0.cgColor }) ?? value // No validation possible
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
                return subtype == Swift.type(of: value) || "\(subtype)" == "\(Swift.type(of: value))" ? value: nil
            }
        case let .enum(type, enumValues, _):
            if let key = value as? String, let value = enumValues[key] {
                return value
            }
            if type != Swift.type(of: value) {
                return nil
            }
            if let value = value as? AnyHashable, let values = Array(enumValues.values) as? [AnyHashable] {
                return values.contains(value) ? value : nil
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
        if "\(self)".hasPrefix("_") {
            // We don't want to mess with private stuff
            return [:]
        }
        // Gather properties
        var allProperties = [String: RuntimeType]()
        var numberOfProperties: CUnsignedInt = 0
        guard let properties = class_copyPropertyList(self, &numberOfProperties) else {
            return [:]
        }
        for i in 0 ..< Int(numberOfProperties) {
            let cprop = properties[i]
            if let cname = property_getName(cprop), let cattribs = property_getAttributes(cprop) {
                var name = String(cString: cname)
                if name.hasPrefix("_") {
                    // We don't want to mess with private stuff
                    continue
                }
                // Get (non-readonly) attributes
                let attribs = String(cString: cattribs).components(separatedBy: ",")
                if attribs.contains("R") {
                    // TODO: check for KVC compliance
                    continue
                }
                let type: RuntimeType
                let typeAttrib = attribs[0]
                switch typeAttrib.characters.dropFirst().first! {
                case "c" where OBJC_BOOL_IS_BOOL == 0, "B":
                    type = RuntimeType(Bool.self)
                    for attrib in attribs where attrib.hasPrefix("Gis") {
                        name = attrib.substring(from: "G".endIndex)
                        break
                    }
                case "c", "i", "s", "l", "q":
                    type = RuntimeType(Int.self)
                case "C", "I", "S", "L", "Q":
                    type = RuntimeType(UInt.self)
                case "f":
                    type = RuntimeType(Float.self)
                case "d":
                    type = RuntimeType(Double.self)
                case "*":
                    type = RuntimeType(UnsafePointer<Int8>.self)
                case "@":
                    if typeAttrib.hasPrefix("T@\"") {
                        let range = "T@\"".endIndex ..< typeAttrib.index(before: typeAttrib.endIndex)
                        let className = typeAttrib.substring(with: range)
                        if let cls = NSClassFromString(className) {
                            type = RuntimeType(cls)
                            break
                        }
                        if className.hasPrefix("<") {
                            let range = "<".endIndex ..< className.index(before: className.endIndex)
                            let protocolName = className.substring(with: range)
                            if let proto = NSProtocolFromString(protocolName) {
                                type = RuntimeType(proto)
                                break
                            }
                        }
                    }
                    type = RuntimeType(AnyObject.self)
                case "#":
                    type = RuntimeType(AnyClass.self)
                case ":":
                    type = RuntimeType(Selector.self)
                case "{":
                    if typeAttrib.hasPrefix("T{CGPoint") {
                        type = RuntimeType(CGPoint.self)
                        if allProperties[name] == nil {
                            allProperties["\(name).x"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).y"] = RuntimeType(CGFloat.self)
                        }
                    } else if typeAttrib.hasPrefix("T{CGSize") {
                        type = RuntimeType(CGSize.self)
                        if allProperties[name] == nil {
                            allProperties["\(name).width"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).height"] = RuntimeType(CGFloat.self)
                        }
                    } else if typeAttrib.hasPrefix("T{CGRect") {
                        type = RuntimeType(CGRect.self)
                        if allProperties[name] == nil {
                            allProperties["\(name).x"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).y"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).width"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).height"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).origin"] = RuntimeType(CGPoint.self)
                            allProperties["\(name).size"] = RuntimeType(CGSize.self)
                        }
                    } else if typeAttrib.hasPrefix("T{UIEdgeInsets") {
                        type = RuntimeType(UIEdgeInsets.self)
                        if allProperties[name] == nil {
                            allProperties["\(name).top"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).left"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).bottom"] = RuntimeType(CGFloat.self)
                            allProperties["\(name).right"] = RuntimeType(CGFloat.self)
                        }
                    } else if typeAttrib.hasPrefix("T{CGAffineTransform") {
                        // TODO: provide some kind of access to transform members
                        type = RuntimeType(CGAffineTransform.self)
                    } else if typeAttrib.hasPrefix("T{CATransform3D") {
                        // TODO: provide some kind of access to transform members
                        type = RuntimeType(CATransform3D.self)
                    } else {
                        // Generic struct type
                        type = RuntimeType(NSValue.self)
                    }
                default:
                    // Unsupported type
                    continue
                }
                // Store
                if allProperties[name] == nil {
                    allProperties[name] = type
                }
            }
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
