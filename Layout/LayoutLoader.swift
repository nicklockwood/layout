//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

typealias LayoutLoaderCallback = (LayoutNode?, LayoutError?) -> Void

// Cache for previously loaded layouts
private var cache = [URL: Layout]()
private let queue = DispatchQueue(label: "com.Layout")

// API for loading a layout XML file
class LayoutLoader {
    private var _xmlURL: URL!
    private var _projectDirectory: URL?
    private var _dataTask: URLSessionDataTask?
    private var _state: Any = ()
    private var _constants: [String: Any] = [:]
    private var _strings: [String: String]?

    private func setNode(
        withLayout layout: Layout?,
        error: Error?,
        state: Any,
        constants: [String: Any],
        completion: (LayoutNode?, LayoutError?) -> Void
    ) {
        _state = state
        _constants = constants
        guard let layout = layout else {
            if let error = error {
                completion(nil, LayoutError(error))
            }
            return
        }
        do {
            let layoutNode = try LayoutNode(layout: layout)
            layoutNode.constants = constants
            layoutNode.state = state
            completion(layoutNode, nil)
        } catch {
            completion(nil, LayoutError(error))
        }
    }

    private func setNode(
        withXMLData data: Data?,
        relativeTo: String?,
        error: Error?,
        state: Any,
        constants: [String: Any],
        completion: (LayoutNode?, LayoutError?) -> Void
    ) {
        do {
            guard let data = data else {
                try error.map { throw $0 }
                return
            }
            let layout = try Layout(xmlData: data, relativeTo: relativeTo)
            queue.async { cache[self._xmlURL] = layout }
            setNode(
                withLayout: layout,
                error: error,
                state: state,
                constants: constants,
                completion: completion
            )
        } catch {
            _state = state
            _constants = constants
            completion(nil, LayoutError(error))
        }
    }

    public func loadLayout(
        named: String,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file,
        state: Any = (),
        constants: [String: Any] = [:]) throws -> LayoutNode {
        assert(Thread.isMainThread)
        guard let xmlURL = bundle.url(forResource: named, withExtension: nil) ??
            bundle.url(forResource: named, withExtension: "xml") else {
            throw LayoutError.message("No layout XML file found for `\(named)`")
        }
        var _node: LayoutNode?
        var _error: Error?
        loadLayout(
            withContentsOfURL: xmlURL,
            relativeTo: relativeTo,
            state: state,
            constants: constants
        ) { node, error in
            _node = node
            _error = error
        }
        if let error = _error {
            throw error
        }
        return _node!
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
        _state = state
        _constants = constants
        _strings = nil

        // If it's a bundle resource url, replacw with equivalent source url
        if xmlURL.isFileURL {
            let bundlePath = Bundle.main.bundleURL.absoluteString
            if xmlURL.absoluteString.hasPrefix(bundlePath) {
                if _projectDirectory == nil, let relativeTo = relativeTo,
                    let projectDirectory = findProjectDirectory(at: "\(relativeTo)") {
                    _projectDirectory = projectDirectory
                }
                if let projectDirectory = _projectDirectory {
                    var parts = xmlURL.absoluteString
                        .substring(from: bundlePath.endIndex).components(separatedBy: "/")
                    for (i, part) in parts.enumerated().reversed() {
                        if part.hasSuffix(".bundle") {
                            parts.removeFirst(i + 1)
                            break
                        }
                    }
                    let path = parts.joined(separator: "/")
                    do {
                        if let url = try findSourceURL(forRelativePath: path, in: projectDirectory) {
                            _xmlURL = url
                        }
                    } catch {
                        completion(nil, LayoutError(error))
                        return
                    }
                }
            }
        }

        // Check cache
        var layout: Layout?
        queue.sync { layout = cache[_xmlURL] }
        if let layout = layout {
            setNode(
                withLayout: layout,
                error: nil,
                state: state,
                constants: constants,
                completion: completion
            )
            return
        }

        // Load synchronously if it's a local file and we're on the main thread already
        if _xmlURL.isFileURL, Thread.isMainThread {
            let data: Data?
            let error: Error?
            do {
                data = try Data(contentsOf: _xmlURL)
                error = nil
            } catch let _error {
                data = nil
                error = _error
            }
            setNode(
                withXMLData: data,
                relativeTo: relativeTo ?? xmlURL.path, // TODO: is this fallback correct?
                error: error,
                state: state,
                constants: constants,
                completion: completion
            )
            return
        }

        // Load asynchronously
        let xmlURL = _xmlURL!
        _dataTask = URLSession.shared.dataTask(with: xmlURL) { data, _, error in
            DispatchQueue.main.async {
                if self._xmlURL != xmlURL {
                    return // Must have been cancelled
                }
                self.setNode(
                    withXMLData: data,
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
        queue.sync { cache.removeAll() }
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

    public func loadLocalizedStrings() throws -> [String: String] {
        if let strings = _strings {
            return strings
        }
        var path = "Localizable.strings"
        let localizedPath = Bundle.main.path(forResource: "Localizable", ofType: "strings")
        if let resourcePath = Bundle.main.resourcePath, let localizedPath = localizedPath {
            path = localizedPath.substring(from: resourcePath.endIndex)
        }
        if let projectDirectory = _projectDirectory,
            let url = try findSourceURL(forRelativePath: path, in: projectDirectory) {
            _strings = NSDictionary(contentsOf: url) as? [String: String] ?? [:]
            return _strings!
        }
        if let stringsFile = localizedPath {
            _strings = NSDictionary(contentsOfFile: stringsFile) as? [String: String] ?? [:]
            return _strings!
        }
        return [:]
    }

    public func setSourceURL(_ sourceURL: URL, for path: String) {
        _setSourceURL(sourceURL, for: path)
    }
}

#if arch(i386) || arch(x86_64)

    // MARK: Only applicable when running in the simulator

    private var _projectDirectory: URL?
    private var _sourceURLCache = [String: URL]()

    private func findProjectDirectory(at path: String) -> URL? {
        if let projectDirectory = _projectDirectory, path.hasPrefix(projectDirectory.path) {
            return projectDirectory
        }
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
                _projectDirectory = url
                return url
            }
        }
        return findProjectDirectory(at: parent.path)
    }

    private func findSourceURL(forRelativePath path: String, in directory: URL, usingCache: Bool = true) throws -> URL? {
        if let url = _sourceURLCache[path], FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return nil
        }
        var parts = URL(fileURLWithPath: path).pathComponents
        if parts[0] == "/" {
            parts.removeFirst()
        }
        var results = [URL]()
        for file in files where !file.hasSuffix(".build") && !file.hasSuffix(".app") {
            let directory = directory.appendingPathComponent(file)
            if file == parts[0] {
                if parts.count == 1 {
                    results.append(directory) // Not actually a directory
                    continue
                }
                try findSourceURL(
                    forRelativePath: parts.dropFirst().joined(separator: "/"),
                    in: directory,
                    usingCache: false
                ).map {
                    results.append($0)
                }
            }
            try findSourceURL(
                forRelativePath: path,
                in: directory,
                usingCache: false
            ).map {
                results.append($0)
            }
        }
        guard results.count <= 1 else {
            throw LayoutError.multipleMatches(results, for: path)
        }
        if usingCache {
            guard let url = results.first else {
                throw LayoutError.message("Unable to locate source file for \(path)")
            }
            _sourceURLCache[path] = url
        }
        return results.first
    }

    private func _setSourceURL(_ sourceURL: URL, for path: String) {
        _sourceURLCache[path] = sourceURL
    }

#else

    private func findProjectDirectory(at _: String) -> URL? { return nil }
    private func findSourceURL(forRelativePath _: String, in _: URL) throws -> URL? { return nil }
    private func _setSourceURL(_: URL, for _: String) {}

#endif
