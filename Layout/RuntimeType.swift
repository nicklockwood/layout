//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

public class RuntimeType: NSObject {
    public enum Kind {
        case any(Any.Type)
        case `class`(AnyClass)
        case `struct`(String)
        case pointer(String)
        case `protocol`(Protocol)
        case `enum`(Any.Type, [String: Any])
    }

    public enum Availability {
        case available
        case unavailable(reason: String?)
    }

    public typealias Getter = (_ target: AnyObject, _ key: String) -> Any?
    public typealias Setter = (_ target: AnyObject, _ key: String, _ value: Any) throws -> Void

    public let type: Kind
    public private(set) var availability = Availability.available
    public private(set) var getter: Getter?
    public private(set) var setter: Setter?

    static func unavailable(_ reason: String? = nil) -> RuntimeType {
        let type = RuntimeType(.any(String.self))
        type.availability = .unavailable(reason: reason)
        return type
    }

    @nonobjc private init(_ type: Kind) {
        self.type = type
    }

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

    @nonobjc public init(class: AnyClass) {
        type = .class(`class`)
    }

    @nonobjc public init(_ type: Protocol) {
        self.type = .protocol(type)
    }

    @nonobjc public convenience init?(_ typeName: String) {
        guard let type = typesByName[typeName] ?? NSClassFromString(typeName) else {
            guard let proto = NSProtocolFromString(typeName) else {
                return nil
            }
            self.init(proto)
            return
        }
        self.init(type)
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
                let className: String = String(objCType[range])
                if className.hasPrefix("<") {
                    let range = "<".endIndex ..< className.index(before: className.endIndex)
                    let protocolName: String = String(className[range])
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
            // Can't infer the specific subclass, so ignore it
            return nil
        case ":":
            type = .any(Selector.self)
            getter = { target, key in
                let selector = Selector(key)
                let fn = unsafeBitCast(
                    class_getMethodImplementation(Swift.type(of: target), selector),
                    to: (@convention(c) (AnyObject?, Selector) -> Selector?).self
                )
                return fn(target, selector)
            }
            setter = { target, key, value in
                let chars = key.characters
                let selector = Selector(
                    "set\(String(chars.first!).uppercased())\(String(chars.dropFirst())):"
                )
                let fn = unsafeBitCast(
                    class_getMethodImplementation(Swift.type(of: target), selector),
                    to: (@convention(c) (AnyObject?, Selector, Selector?) -> Void).self
                )
                fn(target, selector, value as? Selector)
            }
        case "{":
            type = .struct(objCType)
        case "^" where objCType.hasPrefix("^{"):
            type = .pointer(String(objCType.unicodeScalars.dropFirst()))
        case "r" where objCType.hasPrefix("r^{"):
            type = .pointer(String(objCType.unicodeScalars.dropFirst(2)))
        default:
            // Unsupported type
            return nil
        }
    }

    @nonobjc public init<T: RawRepresentable>(_ type: T.Type, _ values: [String: T]) {
        self.type = .enum(type, values)
        getter = { target, key in
            (target.value(forKey: key) as? T.RawValue).flatMap { T(rawValue: $0) }
        }
        setter = { target, key, value in
            target.setValue((value as? T)?.rawValue, forKey: key)
        }
    }

    @nonobjc public init<T: Any>(_ type: T.Type, _ values: [String: T]) {
        self.type = .enum(type, values)
    }

    public override var description: String {
        switch availability {
        case .available:
            switch type {
            case let .any(type),
                 let .enum(type, _):
                return "\(type)"
            case let .class(type):
                return "\(type).Type"
            case let .struct(type),
                 let .pointer(type):
                return type
            case let .protocol(proto):
                return "<\(NSStringFromProtocol(proto))>"
            }
        case .unavailable:
            return "<unavailable>"
        }
    }

    public func cast(_ value: Any) -> Any? {
        switch type {
        case let .any(subtype):
            switch subtype {
            case is NSNumber.Type:
                return value as? NSNumber
            case is CGFloat.Type:
                return value as? CGFloat ??
                    (value as? Double).map { CGFloat($0) } ??
                    (value as? NSNumber).map { CGFloat(truncating: $0) }
            case is Double.Type:
                return value as? Double ??
                    (value as? CGFloat).map { Double($0) } ??
                    (value as? NSNumber).map { Double(truncating: $0) }
            case is Float.Type:
                return value as? Float ??
                    (value as? Double).map { Float($0) } ??
                    (value as? NSNumber).map { Float(truncating: $0) }
            case is Int.Type:
                return value as? Int ??
                    (value as? Double).map { Int($0) } ??
                    (value as? NSNumber).map { Int(truncating: $0) }
            case is UInt.Type:
                return value as? UInt ??
                    (value as? Double).map { Int($0) } ??
                    (value as? NSNumber).map { Int(truncating: $0) }
            case is Bool.Type:
                return value as? Bool ??
                    (value as? Double).map { $0 != 0 } ??
                    (value as? NSNumber).map { $0 != 0 }
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
                guard let value = optionalValue(of: value) else {
                    return nil
                }
                return subtype == Swift.type(of: value) || "\(subtype)" == "\(Swift.type(of: value))" ? value : nil
            }
        case let .class(type):
            if let value = value as? AnyClass, value.isSubclass(of: type) {
                return value
            }
            return nil
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
                if let value = optionalValue(of: value), "\(value)".hasPrefix("<CGColor") {
                    return value
                }
                return nil
            case "{CGImage=}":
                if let value = value as? UIImage {
                    return value.cgImage
                }
                if let value = optionalValue(of: value), "\(value)".hasPrefix("<CGImage") {
                    return value
                }
                return nil
            default:
                return value // No validation possible
            }
        case let .enum(type, enumValues):
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

private let typesByName: [String: Any.Type] = [
    "Any": Any.self,
    "String": String.self,
    "Bool": Bool.self,
    "Int": Int.self,
    "UInt": UInt.self,
    "Float": Float.self,
    "Double": Double.self,
    "CGFloat": CGFloat.self,
    "CGColor": CGColor.self,
    "CGImage": CGImage.self,
    "CGPoint": CGPoint.self,
    "CGSize": CGSize.self,
    "CGRect": CGRect.self,
    "CGVector": CGVector.self,
    "CGAffineTransform": CGAffineTransform.self,
    "CATransform3D": CATransform3D.self,
    "UIEdgeInsets": UIEdgeInsets.self,
    "UIOffset": UIOffset.self,
    "Selector": Selector.self,
]
