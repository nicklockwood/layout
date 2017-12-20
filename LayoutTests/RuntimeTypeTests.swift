//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class RuntimeTypeTests: XCTestCase {

    // MARK: Sanitized type names

    func testSanitizeURLName() {
        XCTAssertEqual(sanitizedTypeName("URL"), "url")
    }

    func testSanitizeURLRequestName() {
        XCTAssertEqual(sanitizedTypeName("URLRequest"), "urlRequest")
    }

    func testSanitizeStringName() {
        XCTAssertEqual(sanitizedTypeName("String"), "string")
    }

    func testSanitizeAttributedStringName() {
        XCTAssertEqual(sanitizedTypeName("NSAttributedString"), "nsAttributedString")
    }

    func testSanitizeUINavigationItem_LargeTitleDisplayModeName() {
        XCTAssertEqual(sanitizedTypeName("UINavigationItem.LargeTitleDisplayMode"), "uiNavigationItem_LargeTitleDisplayMode")
    }

    func testSanitizeEmptyName() {
        XCTAssertEqual(sanitizedTypeName(""), "")
    }

    // MARK: Type classification

    func testProtocolType() {
        let runtimeType = RuntimeType(UITableViewDelegate.self)
        guard case .protocol = runtimeType.type else {
            XCTFail()
            return
        }
    }

    func testDynamicProtocolType() {
        let type: Any.Type = UITableViewDelegate.self
        let runtimeType = RuntimeType(type)
        guard case .protocol = runtimeType.type else {
            XCTFail()
            return
        }
    }

    func testArrayType() {
        let runtimeType = RuntimeType([Int].self)
        guard case .array = runtimeType.type else {
            XCTFail()
            return
        }
    }

    func testDynamicArrayType() {
        let type: Any.Type = [Int].self
        let runtimeType = RuntimeType(type)
        guard case .array = runtimeType.type else {
            XCTFail()
            return
        }
    }

    func testArrayTypeByName() {
        guard let runtimeType = RuntimeType.type(named: "Array<Int>") else {
            XCTFail()
            return
        }
        guard case let .array(subtype) = runtimeType.type else {
            XCTFail()
            return
        }
        XCTAssertEqual(subtype, .int)
    }

    func testArrayTypeByShortName() {
        guard let runtimeType = RuntimeType.type(named: "[Int]") else {
            XCTFail()
            return
        }
        guard case let .array(subtype) = runtimeType.type else {
            XCTFail()
            return
        }
        XCTAssertEqual(subtype, .int)
    }

    func testNSArrayTypeByName() {
        guard let runtimeType = RuntimeType.type(named: "NSArray") else {
            XCTFail()
            return
        }
        guard case .array = runtimeType.type else {
            XCTFail()
            return
        }
    }

    // MARK: Type casting

    func testCastProtocol() {
        let runtimeType = RuntimeType(UITableViewDelegate.self)
        XCTAssertNil(runtimeType.cast(NSObject()))
        XCTAssertNil(runtimeType.cast(UITableViewDelegate.self))
        XCTAssertNotNil(runtimeType.cast(UITableViewController()))
    }

    func testCastNSArray() {
        let runtimeType = RuntimeType(NSArray.self)
        XCTAssertNotNil(runtimeType.cast(NSObject())) // Anything can be array-ified
        XCTAssertNotNil(runtimeType.cast(["foo"]))
        XCTAssertNotNil(runtimeType.cast([5, "foo"]))
        XCTAssertNotNil(runtimeType.cast([5]))
        XCTAssertNotNil(runtimeType.cast(NSArray()))
        XCTAssertNotNil(runtimeType.cast([(1, 2, 3)]))
    }

    func testCastDoesntCopyNSArray() {
        let runtimeType = RuntimeType(NSArray.self)
        let array = NSArray(array: [1, 2, 3, "foo", "bar", "baz"])
        XCTAssertTrue(runtimeType.cast(array) as? NSArray === array)
    }

    func testCastIntArray() {
        let runtimeType = RuntimeType([Int].self)
        XCTAssertNil(runtimeType.cast(NSObject()))
        XCTAssertNil(runtimeType.cast(["foo"]))
        XCTAssertNil(runtimeType.cast([5, "foo"]))
        XCTAssertNil(runtimeType.cast([[5]])) // Nested arrays are not flattened
        XCTAssertNotNil(runtimeType.cast([5]))
        XCTAssertNotNil(runtimeType.cast([5.0]))
        XCTAssertNotNil(runtimeType.cast(NSArray()))
        XCTAssertNotNil(runtimeType.cast([String]()))
        XCTAssertEqual(runtimeType.cast(5) as! [Int], [5]) // Stringified and array-ified
    }

    func testCastStringArray() {
        let runtimeType = RuntimeType([String].self)
        XCTAssertNotNil(runtimeType.cast(["foo"]))
        XCTAssertEqual(runtimeType.cast([5]) as! [String], ["5"]) // Anything can be stringified
        XCTAssertEqual(runtimeType.cast("foo") as! [String], ["foo"]) // Is array-ified
        XCTAssertEqual(runtimeType.cast(5) as! [String], ["5"]) // Stringified and array-ified
    }

    func testCastArrayArray() {
        let runtimeType = RuntimeType([[Int]].self)
        XCTAssertNotNil(runtimeType.cast([[5]]))
        XCTAssertNotNil(runtimeType.cast([5]) as? [[Int]]) // Inner values is array-ified
    }
}
