//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class LayoutMountingTests: XCTestCase {

    // MARK: mounting view in view controller

    func testMountUnitializedViewNodeInInitializedViewController() throws {
        let node = LayoutNode()
        let vc = UIViewController()
        _ = vc.view // Initialize VC
        try node.mount(in: vc)
        XCTAssertNotEqual(vc.view, node.view)
    }

    func testMountUnitializedViewNodeInUninitializedViewController() throws {
        let node = LayoutNode()
        let vc = UIViewController()
        try node.mount(in: vc)
        XCTAssertEqual(vc.view, node.view)
    }

    func testMountInitializedViewNodeInUninitializedViewController() throws {
        let node = LayoutNode()
        _ = node.view // Initialize node
        let vc = UIViewController()
        try node.mount(in: vc)
        XCTAssertEqual(vc.view, node.view)
    }

    func testMountInitializedViewNodeInInitializedViewController() throws {
        let node = LayoutNode()
        _ = node.view // Initialize node
        let vc = UIViewController()
        _ = vc.view // Initialize VC
        try node.mount(in: vc)
        XCTAssertNotEqual(vc.view, node.view)
    }

    // MARK: mounting view controller in view controller

    func testMountUninitializedViewControllerNodeInUninitializedViewController() throws {
        let node = try LayoutNode(class: UIViewController.self)
        let vc = UIViewController()
        try node.mount(in: vc)
        XCTAssertNotEqual(vc.view, node.view)
    }

    // MARK: UITableViewController

    func testMountUninitializedViewInUninitializedTableViewController() throws {
        let node = try LayoutNode(class: UIView.self)
        let vc = UITableViewController()
        try node.mount(in: vc)
        XCTAssertNotEqual(vc.view, node.view)
    }

    func testMountInitializedViewInUninitializedTableViewController() throws {
        let node = try LayoutNode(class: UIView.self)
        _ = node.view // Initialize node
        let vc = UITableViewController()
        try node.mount(in: vc)
        XCTAssertNotEqual(vc.view, node.view)
    }

    func testMountInitializedViewInInitializedTableViewController() throws {
        let node = try LayoutNode(class: UIView.self)
        _ = node.view // Initialize node
        let vc = UITableViewController()
        _ = vc.view // Initialize VC
        try node.mount(in: vc)
        XCTAssertNotEqual(vc.view, node.view)
    }

    func testMountUninitializedUITableViewInUninitializedTableViewController() throws {
        let node = try LayoutNode(class: UITableView.self)
        let vc = UITableViewController()
        try node.mount(in: vc)
        XCTAssertEqual(vc.view, node.view)
    }

    func testMountInitializedUITableViewInUninitializedTableViewController() throws {
        let node = try LayoutNode(class: UITableView.self)
        _ = node.view // Initialize node
        let vc = UITableViewController()
        try node.mount(in: vc)
        XCTAssertEqual(vc.view, node.view)
    }

    func testMountUninitializedUITableViewInInitializedTableViewController() throws {
        let node = try LayoutNode(class: UITableView.self)
        let vc = UITableViewController()
        _ = vc.view // Initialize VC
        XCTAssertThrowsError(try node.mount(in: vc)) { error in
            XCTAssert("\(error)".contains("UITableView"))
        }
    }

    func testMountInitializedUITableViewInInitializedTableViewController() throws {
        let node = try LayoutNode(class: UITableView.self)
        _ = node.view // Initialize node
        let vc = UITableViewController()
        _ = vc.view // Initialize VC
        XCTAssertThrowsError(try node.mount(in: vc)) { error in
            XCTAssert("\(error)".contains("UITableView"))
        }
    }
}
