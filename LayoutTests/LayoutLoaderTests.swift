//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

private func createTempDirectory(_ suffix: String) throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(suffix)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
    return directory
}

class LayoutLoaderTests: XCTestCase {

    func testFindProjectDirectory() {
        let loader = LayoutLoader()
        let file = #file
        let path = loader.findProjectDirectory(at: file)
        let expected = URL(fileURLWithPath: file).deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(path, expected)
    }

    func testFindProjectDirectoryIfPathContainsDot() {
        let directory = try! createTempDirectory("foo-4.5/bar")
        let projectURL = directory.deletingLastPathComponent().appendingPathComponent("Project.xcodeproj")
        let fileURL = directory.appendingPathComponent("baz.swift")
        do {
            try "project".data(using: .utf8)!.write(to: projectURL)
            try "file".data(using: .utf8)!.write(to: fileURL)
            let loader = LayoutLoader()
            let path = loader.findProjectDirectory(at: fileURL.path)
            XCTAssertEqual(path, projectURL.deletingLastPathComponent())
        } catch {
            XCTFail("\(error)")
        }
        try! FileManager.default.removeItem(at: directory)
    }

    func testFindXMLSourceFile() {
        let loader = LayoutLoader()
        let file = #file
        guard let projectDirectory = loader.findProjectDirectory(at: file) else {
            XCTFail()
            return
        }
        do {
            loader.clearSourceURLs()
            let sourceURL = try loader.findSourceURL(
                forRelativePath: "Examples.xml",
                in: projectDirectory,
                usingCache: false
            )
            let expected = URL(fileURLWithPath: file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("SampleApp/Examples.xml")
            XCTAssertEqual(sourceURL, expected)
        } catch {
            XCTFail("\(error)")
        }
    }
}
