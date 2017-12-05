//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class LayoutViewControllerTests: XCTestCase {

    /// Test class for layoutDidLoad() backward compatibility test
    class BackwardTestLayoutViewController: LayoutViewController {

        var layoutDidLoadCallCount = 0

        override func layoutDidLoad() {
            layoutDidLoadCallCount += 1
        }
    }

    /// Test class which overrides layoutDidLoad(_:)
    class TestLayoutViewController: BackwardTestLayoutViewController {

        var layoutDidLoadLayoutNode: LayoutNode?
        var layoutDidLoadLayoutNodeCallCount = 0

        override func layoutDidLoad(_ layoutNode: LayoutNode) {
            layoutDidLoadLayoutNodeCallCount += 1
            layoutDidLoadLayoutNode = layoutNode
        }
    }

    func testLayoutDidLoadWithValidXML() throws {
        let viewController = TestLayoutViewController()
        viewController.loadLayout(withContentsOfURL: try url(forXml: "LayoutDidLoad_Valid"))

        XCTAssertNotNil(viewController.layoutDidLoadLayoutNode)
        XCTAssertEqual(viewController.layoutNode, viewController.layoutDidLoadLayoutNode)
        XCTAssertEqual(viewController.layoutDidLoadLayoutNodeCallCount, 1)
        XCTAssertEqual(viewController.layoutDidLoadCallCount, 0)
    }

    func testLayoutDidLoadWithInvalidXML() throws {
        let viewController = TestLayoutViewController()
        viewController.loadLayout(withContentsOfURL: try url(forXml: "LayoutDidLoad_Invalid"))

        XCTAssertNil(viewController.layoutDidLoadLayoutNode)
        XCTAssertEqual(viewController.layoutDidLoadLayoutNodeCallCount, 0)
        XCTAssertEqual(viewController.layoutDidLoadCallCount, 0)
    }

    func testCompatibilityLayoutDidLoadWithValidXML() throws {
        let viewController = BackwardTestLayoutViewController()
        viewController.loadLayout(withContentsOfURL: try url(forXml: "LayoutDidLoad_Valid"))

        XCTAssertEqual(viewController.layoutDidLoadCallCount, 1)
    }

    func testCompatibilityLayoutDidLoadWithInvalidXML() throws {
        let viewController = BackwardTestLayoutViewController()
        viewController.loadLayout(withContentsOfURL: try url(forXml: "LayoutDidLoad_Invalid"))

        XCTAssertEqual(viewController.layoutDidLoadCallCount, 0)
    }

    private func url(forXml name: String) throws -> URL {
        guard let url = Bundle(for: LayoutViewControllerTests.self).url(forResource: name, withExtension: "xml") else {
            throw NSError(domain: "Could not find the following test resource: \(name).xml", code: 0)
        }

        return url
    }
}
