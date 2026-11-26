import Foundation

enum BackgroundDownloadSettings {
    // Keep the old key so existing user preferences continue to work.
    static let enabledKey = "hlsBackgroundDownloadsEnabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        // Background continuation is enabled by default for user-initiated downloads.
        // Preserve an explicit opt-out saved by an existing installation.
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }
}

// Compatibility name used by the HLS background-download test suite and settings UI.
// Keep the implementation in one place so both names share the same persisted key.
typealias HLSBackgroundDownloadSettings = BackgroundDownloadSettings

protocol HLSBackgroundDownloadScheduling: AnyObject {
    func request(
        attemptID: UUID,
        title: String,
        onGranted: @escaping () -> Bool,
        onExpiration: @escaping () -> Void,
        onRejected: @escaping () -> Void
    )
    func updateProgress(attemptID: UUID, completed: Int64, total: Int64, subtitle: String)
    func finish(attemptID: UUID, success: Bool)
}

#if os(iOS) && !targetEnvironment(macCatalyst)
import BackgroundTasks

@available(iOS 26.0, *)
final class HLSBackgroundDownloadCoordinator: HLSBackgroundDownloadScheduling {
    static let shared = HLSBackgroundDownloadCoordinator()

    private final class Request {
        let token = UUID()
        let identifier: String
        let title: String
        var attemptID: UUID?
        var onGranted: (() -> Bool)?
        var onExpiration: (() -> Void)?
        var onRejected: (() -> Void)?
        var task: BGContinuedProcessingTask?
        var expired = false

        init(
            identifier: String,
            attemptID: UUID,
            title: String,
            onGranted: @escaping () -> Bool,
            onExpiration: @escaping () -> Void,
            onRejected: @escaping () -> Void
        ) {
            self.identifier = identifier
            self.attemptID = attemptID
            let normalizedTitle = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            self.title = String(normalizedTitle.prefix(64))
            self.onGranted = onGranted
            self.onExpiration = onExpiration
            self.onRejected = onRejected
        }

        func retire() {
            attemptID = nil
            onGranted = nil
            onExpiration = nil
            onRejected = nil
        }
    }

    private final class Slot {
        var registered = false
        var request: Request?
    }

    private let slots: [Slot]
    private let taskIdentifierPrefix: String?

    private init() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            taskIdentifierPrefix = nil
            slots = []
            return
        }

        let prefix = "\(bundleIdentifier).hls-download"
        taskIdentifierPrefix = prefix
        let createdSlots = (0..<4).map { _ in Slot() }
        slots = createdSlots

        // Continued-processing requests use unique identifiers beneath a
        // registered wildcard, as required by Apple's iOS 26 API.
        let wildcardIdentifier = "\(prefix).*"
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: wildcardIdentifier,
            using: .main
        ) { [weak self] task in
            guard let self, let continuedTask = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.receive(continuedTask)
        }
        for slot in slots {
            slot.registered = registered
        }
        if !registered {
            Logger.shared.log("Could not register continued-processing wildcard \(wildcardIdentifier)", type: "Download")
        }
    }

    func request(
        attemptID: UUID,
        title: String,
        onGranted: @escaping () -> Bool,
        onExpiration: @escaping () -> Void,
        onRejected: @escaping () -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !slots.contains(where: { $0.request?.attemptID == attemptID }) else { return }
        guard let prefix = taskIdentifierPrefix,
              let slot = slots.first(where: { $0.registered && $0.request == nil }) else {
            onRejected()
            return
        }

        let normalizedTitle = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let safeTitle = String(normalizedTitle.prefix(64))
        let identifier = "\(prefix).\(UUID().uuidString)"
        let request = Request(
            identifier: identifier,
            attemptID: attemptID,
            title: safeTitle.isEmpty ? "Downloading video" : safeTitle,
            onGranted: onGranted,
            onExpiration: onExpiration,
            onRejected: onRejected
        )
        slot.request = request
        log("requested", request: request, slot: slot)

        let taskRequest = BGContinuedProcessingTaskRequest(
            identifier: request.identifier,
            title: request.title,
            subtitle: "Preparing download"
        )
        // The HLS downloader hands playlist, key, and segment resources to
        // its OS-owned background URLSession. Continued-processing is only an
        // optional execution/progress allowance; queueing that allowance must
        // never hold the actual download in Eclipse's queue. Fail fast when
        // iOS cannot grant it and let background URLSession own the transfers.
        taskRequest.strategy = .fail
        let token = request.token
        DispatchQueue.global(qos: .utility).async { [weak self, weak slot] in
            do {
                try BGTaskScheduler.shared.submit(taskRequest)
                DispatchQueue.main.async {
                    guard let self, let slot else { return }
                    self.submissionFinished(in: slot, token: token, error: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, let slot else { return }
                    self.submissionFinished(in: slot, token: token, error: error)
                }
            }
        }
    }

    func updateProgress(attemptID: UUID, completed: Int64, total: Int64, subtitle: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let request = slots.compactMap(\.request).first(where: { $0.attemptID == attemptID }),
              !request.expired,
              let task = request.task else { return }
        let boundedTotal = max(1, total)
        task.progress.totalUnitCount = boundedTotal
        task.progress.completedUnitCount = min(max(0, completed), boundedTotal)
        let displaySubtitle = subtitle.contains("://") ? "Downloading video" : String(subtitle.prefix(120))
        task.updateTitle(request.title, subtitle: displaySubtitle)
    }

    func finish(attemptID: UUID, success: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let slot = slots.first(where: { $0.request?.attemptID == attemptID }),
              let request = slot.request else { return }
        log("finished success=\(success && !request.expired)", request: request, slot: slot)
        request.retire()
        if let task = request.task {
            slot.request = nil
            task.expirationHandler = nil
            task.setTaskCompleted(success: success && !request.expired)
        } else {
            slot.request = nil
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: request.identifier)
        }
    }

    private func submissionFinished(in slot: Slot, token: UUID, error: Error?) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let request = slot.request, request.token == token else { return }
        if let error {
            let failure = error as NSError
            let domain = failure.domain == BGTaskScheduler.errorDomain ? "BGTaskScheduler" : "other"
            log("rejected domain=\(domain) code=\(failure.code)", request: request, slot: slot)
            if request.task != nil {
                expire(request, in: slot)
                return
            }
            let onRejected = request.onRejected
            request.retire()
            slot.request = nil
            onRejected?()
        } else if request.attemptID == nil {
            slot.request = nil
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: request.identifier)
        }
    }

    private func receive(_ task: BGContinuedProcessingTask) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let slot = slots.first(where: { $0.request?.identifier == task.identifier }),
              let request = slot.request else {
            task.setTaskCompleted(success: false)
            return
        }
        guard request.task == nil else {
            task.setTaskCompleted(success: false)
            return
        }
        guard request.attemptID != nil else {
            slot.request = nil
            task.setTaskCompleted(success: false)
            return
        }

        request.task = task
        task.progress.totalUnitCount = 1
        task.progress.completedUnitCount = 0
        task.expirationHandler = { [weak self, weak slot, weak request] in
            DispatchQueue.main.async {
                guard let self, let slot, let request else { return }
                self.expire(request, in: slot)
            }
        }
        let granted = request.onGranted?() == true
        log("granted accepted=\(granted)", request: request, slot: slot)
        guard slot.request === request, request.task === task else { return }
        request.onGranted = nil
        if !granted {
            let onRejected = request.onRejected
            request.retire()
            slot.request = nil
            task.expirationHandler = nil
            task.setTaskCompleted(success: false)
            onRejected?()
        }
    }

    private func log(_ event: String, request: Request, slot: Slot) {
        let attempt = request.attemptID?.uuidString ?? "retired"
        let index = slots.firstIndex(where: { $0 === slot }) ?? -1
        Logger.shared.log("BackgroundDownload attempt=\(attempt) slot=\(index) \(event)", type: "Download")
    }

    private func expire(_ request: Request, in slot: Slot) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard slot.request === request, request.attemptID != nil, !request.expired else { return }
        log("expired", request: request, slot: slot)
        request.expired = true
        let onExpiration = request.onExpiration
        request.onExpiration = nil
        onExpiration?()
    }
}
#endif
