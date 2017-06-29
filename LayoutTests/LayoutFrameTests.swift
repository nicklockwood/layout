//
//  LayoutFrameTests.swift
//  Layout
//
//  Created by Nick Lockwood on 23/06/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import XCTest
@testable import Layout

class LayoutFrameTests: XCTestCase {
    
    func testLayoutFrameMatchesView() {
        let frame = CGRect(x: 100, y: 50, width: 200, height: 300)
        let view = UIView(frame: frame)
        let node = LayoutNode(view: view)

        // Test unmounted view
        XCTAssertEqual(view.frame, frame)
        XCTAssertEqual(node.frame, view.frame)

        // Test mounted view
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        try! node.mount(in: superview)
        XCTAssertEqual(view.frame, frame)
        XCTAssertEqual(node.frame, view.frame)
    }

    func testLayoutFrameSizeMatchesView() {
        let view = UIView(frame: CGRect(x: 100, y: 50, width: 200, height: 300))
        let node = LayoutNode(view: view, expressions: ["left": "5", "top": "15"])
        let expectedFrame = CGRect(x: 5, y: 15, width: 200, height: 300)

        // Test unmounted view
        XCTAssertEqual(view.frame.size, expectedFrame.size)
        XCTAssertEqual(node.frame, expectedFrame)

        // Test mounted view
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        try! node.mount(in: superview)
        XCTAssertEqual(view.frame, expectedFrame)
        XCTAssertEqual(node.frame, view.frame)
    }

    func testLayoutFrameOriginMatchesView() {
        let view = UIView(frame: CGRect(x: 100, y: 50, width: 200, height: 300))
        let node = LayoutNode(view: view, expressions: ["width": "5", "height": "15"])
        let expectedFrame = CGRect(x: 100, y: 50, width: 5, height: 15)

        // Test unmounted view
        XCTAssertEqual(view.frame.origin, expectedFrame.origin)
        XCTAssertEqual(node.frame, expectedFrame)

        // Test mounted view
        let superview = UIView()
        try! node.mount(in: superview)
        XCTAssertEqual(view.frame, expectedFrame)
        XCTAssertEqual(node.frame, view.frame)
    }

    func testLayoutFrameTracksView() {
        var frame = CGRect(x: 100, y: 50, width: 200, height: 300)
        let view = UIView(frame: frame)
        let node = LayoutNode(view: view)
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        superview.addSubview(view)

        // Test initial frame
        XCTAssertEqual(view.frame, frame)
        XCTAssertEqual(node.frame, view.frame)

        // Test updated frame
        frame = CGRect(x: 20, y: 15, width: 150, height: 400)
        view.frame = frame
        XCTAssertEqual(view.frame, frame)
        XCTAssertEqual(node.frame, view.frame)
    }
}
