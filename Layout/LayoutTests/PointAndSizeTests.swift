//
//  PointAndSizeTests.swift
//  Layout
//
//  Created by Nick Lockwood on 19/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import XCTest
@testable import Layout

class PointAndSizeTests: XCTestCase {
    
    func testGetContentOffset() {
        let scrollView = UIScrollView()
        let node = LayoutNode(view: scrollView)
        XCTAssertEqual(try node.value(forSymbol: "contentOffset") as? CGPoint, scrollView.contentOffset)
    }

    func testGetContentOffsetX() {
        let scrollView = UIScrollView()
        let node = LayoutNode(view: scrollView)
        XCTAssertEqual(try node.doubleValue(forSymbol: "contentOffset.x"), Double(scrollView.contentOffset.x))
    }

    func testSetContentOffset() {
        let offset =  CGPoint(x: 5, y: 10)
        let node = LayoutNode(
            view: UIScrollView(),
            state: ["offset": offset],
            expressions: ["contentOffset": "offset"]
        )
        XCTAssertTrue(node.validate().isEmpty)
        XCTAssertEqual(try node.value(forSymbol: "offset") as? CGPoint, offset)
        XCTAssertEqual(try node.value(forSymbol: "contentOffset") as? CGPoint, offset)
    }

    func testSetContentOffsetX() {
        let node = LayoutNode(
            view: UIScrollView(),
            expressions: ["contentOffset.x": "5"]
        )
        XCTAssertTrue(node.validate().isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "contentOffset.x"), 5)
    }

    func testGetContentSize() {
        let scrollView = UIScrollView()
        let node = LayoutNode(view: scrollView)
        XCTAssertEqual(try node.value(forSymbol: "contentSize") as? CGSize, scrollView.contentSize)
    }

    func testGetContentSizeWidth() {
        let scrollView = UIScrollView()
        let node = LayoutNode(view: scrollView)
        XCTAssertEqual(try node.doubleValue(forSymbol: "contentSize.width"), Double(scrollView.contentSize.width))
    }

    func testSetContentSize() {
        let size =  CGSize(width: 5, height: 10)
        let node = LayoutNode(
            view: UIScrollView(),
            state: ["size": size],
            expressions: ["contentSize": "size"]
        )
        XCTAssertTrue(node.validate().isEmpty)
        XCTAssertEqual(try node.value(forSymbol: "size") as? CGSize, size)
        XCTAssertEqual(try node.value(forSymbol: "contentSize") as? CGSize, size)
    }

    func testSetContentSizeX() {
        let node = LayoutNode(
            view: UIScrollView(),
            expressions: ["contentSize.width": "5"]
        )
        XCTAssertTrue(node.validate().isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "contentSize.width"), 5)
    }
}
