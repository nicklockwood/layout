//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

typealias LayoutLoaderCallback = (LayoutNode?, LayoutError?) -> Void

// Cache for previously loaded layouts
private var cache = [URL: Layout]()
private let queue = DispatchQueue(label: "com.Layout")

// Internal API for converting a path to a full URL
func urlFromString(_ path: String) -> URL {
    if let url = URL(string: path), url.scheme != nil {
        return url
    }

    // Check for scheme
    if path.contains(":") {
        let path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        if let url = URL(string: path) {
            return url
        }
    }

    // Assume local path
    let path = path.removingPercentEncoding ?? path
    if path.hasPrefix("~") {
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    } else if (path as NSString).isAbsolutePath {
        return URL(fileURLWithPath: path)
    } else {
        return Bundle.main.resourceURL!.appendingPathComponent(path)
    }
}

private extension Layout {

    /// Merges the contents of the specified layout into this one
    /// Will fail if the layout class is not a subclass of this one
    func merged(with layout: Layout) throws -> Layout {
        if let path = xmlPath {
            throw LayoutError("Cannot extend `\(className)` template until content for `\(path)` has been loaded.")
        }
        let newClass: AnyClass = try layout.getClass()
        let oldClass: AnyClass = try getClass()
        guard newClass.isSubclass(of: oldClass) else {
            throw LayoutError("Cannot replace \(oldClass) with \(newClass)")
        }
        var expressions = self.expressions
        for (key, value) in layout.expressions {
            expressions[key] = value
        }
        var parameters = self.parameters
        for (key, value) in layout.parameters {
            parameters[key] = value
        }
        return Layout(
            className: layout.className,
            outlet: layout.outlet ?? outlet,
            expressions: expressions,
            parameters: parameters,
            children: children + layout.children,
            xmlPath: layout.xmlPath,
            templatePath: templatePath,
            relativePath: layout.relativePath // TODO: is this correct?
        )
    }

    /// Recursively load all nested layout templates
    func processTemplates(completion: @escaping (Layout?, LayoutError?) -> Void) {
        var result = self
        var error: LayoutError?
        var requestCount = 1 // Offset to 1 initially to prevent premature completion
        func didComplete() {
            requestCount -= 1
            if requestCount == 0 {
                completion(error == nil ? result : nil, error)
            }
        }
        for (index, child) in children.enumerated() {
            requestCount += 1
            child.processTemplates { layout, _error in
                if _error != nil {
                    error = _error
                } else if let layout = layout {
                    result.children[index] = layout
                }
                didComplete()
            }
        }
        if let templatePath = templatePath {
            requestCount += 1
            LayoutLoader().loadLayout(withContentsOfURL: urlFromString(templatePath)) { layout, _error in
                if _error != nil {
                    error = _error
                } else if let layout = layout {
                    do {
                        result = try layout.merged(with: result)
                    } catch let _error {
                        error = LayoutError(_error)
                    }
                }
                didComplete()
            }
        }
        didComplete()
    }
}

// API for loading a layout XML file
class LayoutLoader {
    private var _xmlURL: URL!
    private var _projectDirectory: URL?
    private var _dataTask: URLSessionDataTask?
    private var _state: Any = ()
    private var _constants: [String: Any] = [:]
    private var _strings: [String: String]?

    // MARK: LayoutNode loading

    public func loadLayoutNode(
        named: String,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file,
        state: Any = (),
        constants: [String: Any] = [:]
    ) throws -> LayoutNode {
        _state = state
        _constants = constants

        let layout = try loadLayout(
            named: named,
            bundle: bundle,
            relativeTo: relativeTo
        )
        return try LayoutNode(
            layout: layout,
            state: state,
            constants: constants
        )
    }

    public func loadLayoutNode(
        withContentsOfURL xmlURL: URL,
        relativeTo: String? = #file,
        state: Any = (),
        constants: [String: Any] = [:],
        completion: @escaping LayoutLoaderCallback
    ) {
        _state = state
        _constants = constants

        loadLayout(
            withContentsOfURL: xmlURL,
            relativeTo: relativeTo,
            completion: { [weak self] layout, error in
                self?._state = state
                self?._constants = constants
                do {
                    guard let layout = layout else {
                        if let error = error {
                            throw error
                        }
                        return
                    }
                    try completion(LayoutNode(
                        layout: layout,
                        state: state,
                        constants: constants
                    ), nil)
                } catch {
                    completion(nil, LayoutError(error))
                }
            }
        )
    }

    public func reloadLayoutNode(withCompletion completion: @escaping LayoutLoaderCallback) {
        queue.sync { cache.removeAll() }
        guard let xmlURL = _xmlURL, _dataTask == nil else {
            completion(nil, nil)
            return
        }
        loadLayoutNode(
            withContentsOfURL: xmlURL,
            relativeTo: nil,
            state: _state,
            constants: _constants,
            completion: completion
        )
    }

    // MARK: Layout loading

    public func loadLayout(
        named: String,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file
    ) throws -> Layout {
        assert(Thread.isMainThread)
        guard let xmlURL = bundle.url(forResource: named, withExtension: nil) ??
            bundle.url(forResource: named, withExtension: "xml") else {
            throw LayoutError.message("No layout XML file found for `\(named)`")
        }
        var _layout: Layout?
        var _error: Error?
        loadLayout(
            withContentsOfURL: xmlURL,
            relativeTo: relativeTo
        ) { layout, error in
            _layout = layout
            _error = error
        }
        if let error = _error {
            throw error
        }
        guard let layout = _layout else {
            throw LayoutError("Unable to synchronously load layout `\(named)`. It may depend on a remote template. Try  `loadLayout(withContentsOfURL:)` instead.")
        }
        return layout
    }

    public func loadLayout(
        withContentsOfURL xmlURL: URL,
        relativeTo: String? = #file,
        completion: @escaping (Layout?, LayoutError?) -> Void
    ) {
        _dataTask?.cancel()
        _dataTask = nil
        _xmlURL = xmlURL
        _strings = nil

        func processLayoutData(_ data: Data) throws {
            assert(Thread.isMainThread) // TODO: can we parse XML in the background instead?
            let layout = try Layout(xmlData: data, relativeTo: relativeTo ?? _xmlURL.path)
            queue.async { cache[self._xmlURL] = layout }
            layout.processTemplates(completion: completion)
        }

        // If it's a bundle resource url, replace with equivalent source url
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
            completion(layout, nil)
            return
        }

        // Load synchronously if it's a local file and we're on the main thread already
        if _xmlURL.isFileURL, Thread.isMainThread {
            do {
                let data = try Data(contentsOf: _xmlURL)
                try processLayoutData(data)
            } catch let error {
                completion(nil, LayoutError(error))
            }
            return
        }

        // Load asynchronously
        let xmlURL = _xmlURL!
        _dataTask = URLSession.shared.dataTask(with: xmlURL) { data, _, error in
            DispatchQueue.main.async {
                self._dataTask = nil
                if self._xmlURL != xmlURL {
                    return // Must have been cancelled
                }
                do {
                    guard let data = data else {
                        if let error = error {
                            throw error
                        }
                        return
                    }
                    try processLayoutData(data)
                } catch let error {
                    completion(nil, LayoutError(error))
                }
            }
        }
        _dataTask?.resume()
    }

    // MARK: String loading

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

    // MARK: Internal APIs exposed for LayoutViewController

    func setSourceURL(_ sourceURL: URL, for path: String) {
        _setSourceURL(sourceURL, for: path)
    }

    func clearSourceURLs() {
        _clearSourceURLs()
    }
}

#if arch(i386) || arch(x86_64)

    // MARK: Only applicable when running in the simulator

    private var layoutSettings: [String: Any] {
        get { return UserDefaults.standard.dictionary(forKey: "com.Layout") ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "com.Layout") }
    }

    private var _projectDirectory: URL? {
        didSet {
            let path = _projectDirectory?.path
            if path != layoutSettings["projectDirectory"] as? String {
                sourcePaths.removeAll()
                layoutSettings["projectDirectory"] = path
            }
        }
    }

    private var _sourcePaths: [String: String] = {
        layoutSettings["sourcePaths"] as? [String: String] ?? [:]
    }()

    private var sourcePaths: [String: String] {
        get { return _sourcePaths }
        set {
            _sourcePaths = newValue
            layoutSettings["sourcePaths"] = _sourcePaths
        }
    }

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
        if let filePath = sourcePaths[path], FileManager.default.fileExists(atPath: filePath) {
            return URL(fileURLWithPath: filePath)
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
            _setSourceURL(url, for: path)
        }
        return results.first
    }

    private func _setSourceURL(_ sourceURL: URL, for path: String) {
        guard sourceURL.isFileURL else {
            preconditionFailure()
        }
        sourcePaths[path] = sourceURL.path
    }

    private func _clearSourceURLs() {
        sourcePaths.removeAll()
    }

#else

    private func findProjectDirectory(at _: String) -> URL? { return nil }
    private func findSourceURL(forRelativePath _: String, in _: URL) throws -> URL? { return nil }
    private func _setSourceURL(_: URL, for _: String) {}
    private func _clearSourceURLs() {}

#endif
