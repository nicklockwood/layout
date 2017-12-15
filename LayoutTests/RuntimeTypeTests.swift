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
        XCTAssertNotNil(runtimeType.cast([(1,2,3)]))
    }
}

