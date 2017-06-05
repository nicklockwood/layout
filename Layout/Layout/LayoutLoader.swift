//
//  LayoutViewController.swift
//  Layout
//
//  Created by Nick Lockwood on 10/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import Foundation

typealias LayoutLoaderCallback = (LayoutNode?, LayoutError?) -> Void

// API for loading a layout XML file
class LayoutLoader {

    private var _xmlURL: URL?
    private var _projectDirectory: URL?
    private var _dataTask: URLSessionDataTask?
    private var _state: Any = ()
    private var _constants: [String: Any] = [:]
    private var _strings: [String: String]?

    private func setNodeWithXMLData(
        _ data: Data?,
        relativeTo: String?,
        error: Error?,
        state: Any,
        constants: [String: Any],
        completion: (LayoutNode?, LayoutError?) -> Void
    ) {
        _state = state
        _constants = constants
        guard let data = data else {
            if let error = error {
                completion(nil, LayoutError(error))
            }
            return
        }
        do {
            let layoutNode = try LayoutNode.with(xmlData: data, relativeTo: relativeTo)
            layoutNode.constants = constants
            layoutNode.state = state
            completion(layoutNode, nil)
        } catch {
            completion(nil, LayoutError(error))
        }
    }

    public func loadLayout(
        withContentsOfURL xmlURL: URL,
        relativeTo: String? = #file,
        state: Any = (),
        constants: [String: Any] = [:],
        completion: @escaping LayoutLoaderCallback
    ) {
        _dataTask?.cancel()
        _dataTask = nil
        _xmlURL = xmlURL
        if xmlURL.isFileURL {
            if let relativeTo = relativeTo {
                let bundlePath = Bundle.main.bundleURL.absoluteString
                if xmlURL.absoluteString.hasPrefix(bundlePath),
                    let projectDirectory = findProjectDirectory(at: "\(relativeTo)") {
                    _projectDirectory = projectDirectory
                    let path = xmlURL.absoluteString.substring(from: bundlePath.endIndex)
                    guard let url = findSourceURL(forRelativePath: path, in: projectDirectory) else {
                        completion(nil, .message("Unable to locate source file for \(path)"))
                        return
                    }
                    _xmlURL = url
                }
            }
            if Thread.isMainThread {
                let data: Data?
                let error: Error?
                do {
                    data = try Data(contentsOf: _xmlURL!)
                    error = nil
                } catch let _error {
                    data = nil
                    error = _error
                }
                setNodeWithXMLData(
                    data,
                    relativeTo: relativeTo ?? xmlURL.path,
                    error: error,
                    state: state,
                    constants: constants,
                    completion: completion
                )
                return
            }
        }
        _dataTask = URLSession.shared.dataTask(with: xmlURL) { data, response, error in
            DispatchQueue.main.async {
                if self._xmlURL != xmlURL {
                    return // Must have been cancelled
                }
                self.setNodeWithXMLData(
                    data,
                    relativeTo: relativeTo,
                    error: error,
                    state: state,
                    constants: constants,
                    completion: completion
                )
                self._dataTask = nil
            }
        }
        _dataTask?.resume()
    }

    public func reloadLayout(withCompletion completion: @escaping LayoutLoaderCallback) {
        guard let xmlURL = _xmlURL, _dataTask == nil else {
            completion(nil, nil)
            return
        }
        loadLayout(
            withContentsOfURL: xmlURL,
            relativeTo: nil,
            state: _state,
            constants: _constants,
            completion: completion
        )
    }

    public var localizedStrings: [String: String] {
        if let strings = _strings {
            return strings
        }
        var stringsPath = "Localizable.strings"
        if let resourcePath = Bundle.main.resourcePath,
            let localizedPath = Bundle.main.path(forResource: "Localizable", ofType: "strings") {
            stringsPath = localizedPath.substring(from: resourcePath.endIndex)
        }
        if let projectDirectory = _projectDirectory,
            let url = findSourceURL(forRelativePath: stringsPath, in: projectDirectory) {
            _strings = NSDictionary(contentsOf: url) as? [String: String] ?? [:]
            return _strings!
        }
        if let stringsFile = Bundle.main.path(forResource: "Localizable", ofType: "strings") {
            _strings = NSDictionary(contentsOfFile: stringsFile) as? [String: String] ?? [:]
            return _strings!
        }
        return [:]
    }

    #if arch(i386) || arch(x86_64)

    // MARK: Only applicable when running in the simulator

    private func findProjectDirectory(at path: String) -> URL? {
        var url = URL(fileURLWithPath: path)
        if !url.pathExtension.isEmpty {
            url = url.deletingLastPathComponent()
        }
        if url.lastPathComponent.isEmpty {
            return nil
        }
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            return nil
        }
        let parent = url.deletingLastPathComponent()
        for file in files {
            let pathExtension = URL(fileURLWithPath: file).pathExtension
            if pathExtension == "xcodeproj" || pathExtension == "xcworkspace" {
                if let url = findProjectDirectory(at: parent.path) {
                    return url
                }
                return url
            }
        }
        return findProjectDirectory(at: parent.path)
    }

    private func findSourceURL(forRelativePath path: String, in directory: URL) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return nil
        }
        var parts = URL(fileURLWithPath: path).pathComponents
        if parts[0] == "/" {
            parts.removeFirst()
        }
        for file in files {
            let directory = directory.appendingPathComponent(file)
            if file == parts[0] {
                if parts.count == 1 {
                    return directory // Not actually a directory
                }
                if let result = findSourceURL(forRelativePath: parts.dropFirst().joined(separator: "/"), in: directory) {
                    return result
                }
            }
            if let result = findSourceURL(forRelativePath: path, in: directory) {
                return result
            }
        }
        return nil
    }

    #else

    private func findProjectDirectory(at path: String) -> URL? { return nil }
    private func findSourceURL(forRelativePath path: String, in directory: URL) -> URL? { return nil }

    #endif
}
