//  Copyright © 2018 Schibsted. All rights reserved.

import Foundation

/// A basic wrapper around a VNODE dispatch source
/// Every time the file is written to, a callback gets invoked
class FileWatcher {
    private let _url: URL
    private let _event: DispatchSource.FileSystemEvent
    private let _queue: DispatchQueue
    
    private var _source: DispatchSourceFileSystemObject?
    
    public var fileChanged: (() -> Void)? {
        willSet {
            _source?.cancel()
            _source = nil
        }
        didSet {
            startObservingFileChangesIfPossible()
        }
    }
    
    init?(with url: URL,
          observing event: DispatchSource.FileSystemEvent = .write,
          queue: DispatchQueue = .global()) {
        _url = url
        _event = event
        _queue = queue
        
        guard fileExists() else { return nil }
    }
    
    deinit {
        _source?.cancel()
    }
    
    private func fileExists() -> Bool {
        return _url.isFileURL && FileManager.default.fileExists(atPath: _url.path)
    }
    
    private func startObservingFileChangesIfPossible() {
        guard fileExists() else { return }
        guard let fileChanged = fileChanged else { return }
        
        let descriptor = open(_url.path, O_EVTONLY)
        
        guard descriptor > 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: _event, queue: _queue)
        _source = source
        
        source.setEventHandler { fileChanged() }
        
        source.setCancelHandler() { close(descriptor) }
        
        source.resume()
    }
}
