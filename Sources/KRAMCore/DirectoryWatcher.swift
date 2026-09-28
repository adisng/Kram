import Foundation

/// Watches a single directory for filesystem changes using FSEvents.
/// Events are debounced so that a burst of rapid changes (e.g. dragging
/// 20 files at once) collapses into a single `onChange` callback.
public final class DirectoryWatcher {

    // MARK: - Public Constants

    /// Default quiet window after the last event before `onChange` fires.
    public static let defaultDebounceInterval: TimeInterval = 0.8

    // MARK: - Private State

    private let directory: URL
    private let debounceInterval: TimeInterval
    private var onChange: (() -> Void)?

    private var eventStream: FSEventStreamRef?
    private let callbackQueue = DispatchQueue(label: "com.kram.directorywatcher", qos: .utility)
    private var debounceItem: DispatchWorkItem?
    private var isRunning = false

    // MARK: - Init

    public init(directory: URL, debounceInterval: TimeInterval = DirectoryWatcher.defaultDebounceInterval) {
        self.directory = directory
        self.debounceInterval = debounceInterval
    }

    // MARK: - Public API

    /// Starts watching. `onChange` is called on a background queue after the
    /// debounce window elapses with no further events.
    /// Must be called from the main thread (or a thread with a run loop).
    public func start(onChange: @escaping () -> Void) throws {
        guard !isRunning else { return }
        self.onChange = onChange

        // FSEvents C callback — must be a plain function or closure with no captures;
        // we forward via the `info` context pointer which holds `self`.
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.handleEvent()
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let paths = [directory.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,   // latency: coarse pre-debounce window (seconds)
            flags
        ) else {
            throw KRAMError.operationFailed(source: directory.path, reason: "Unable to create FSEvents stream")
        }

        self.eventStream = stream
        FSEventStreamSetDispatchQueue(stream, callbackQueue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.eventStream = nil
            throw KRAMError.operationFailed(source: directory.path, reason: "Unable to start FSEvents stream")
        }
        isRunning = true
    }

    /// Stops the watcher and cancels any pending debounce callback.
    public func stop() {
        guard isRunning else { return }
        isRunning = false

        debounceItem?.cancel()
        debounceItem = nil

        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    // MARK: - Private

    private func handleEvent() {
        // Cancel any in-flight debounce timer and reschedule
        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceItem = item
        callbackQueue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }
}
