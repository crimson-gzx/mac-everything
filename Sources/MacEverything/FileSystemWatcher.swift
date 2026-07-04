import CoreServices
import Foundation

struct FileSystemChange: Sendable {
    let paths: [String]
    let requiresFullRescan: Bool
}

final class FileSystemWatcher: @unchecked Sendable {
    private let paths: [String]
    private let onChange: @Sendable (FileSystemChange) -> Void
    private let queue = DispatchQueue(label: "MacEverything.FSEvents")
    private var stream: FSEventStreamRef?

    init(paths: [URL], onChange: @escaping @Sendable (FileSystemChange) -> Void) {
        self.paths = paths.map(\.path)
        self.onChange = onChange
    }

    func start() {
        guard stream == nil, !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, eventCount, rawPaths, eventFlags, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(info).takeUnretainedValue()
            let cfPaths = Unmanaged<CFArray>.fromOpaque(rawPaths).takeUnretainedValue()
            let paths = (cfPaths as NSArray).compactMap { $0 as? String }

            var requiresFullRescan = false
            for index in 0..<eventCount {
                let flags = eventFlags[index]
                let rescanFlags = FSEventStreamEventFlags(
                    kFSEventStreamEventFlagMustScanSubDirs |
                    kFSEventStreamEventFlagUserDropped |
                    kFSEventStreamEventFlagKernelDropped |
                    kFSEventStreamEventFlagRootChanged
                )
                if flags & rescanFlags != 0 {
                    requiresFullRescan = true
                    break
                }
            }

            watcher.onChange(FileSystemChange(paths: paths, requiresFullRescan: requiresFullRescan))
        }

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagWatchRoot |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else { return }

        stream = newStream
        FSEventStreamSetDispatchQueue(newStream, queue)
        FSEventStreamStart(newStream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
