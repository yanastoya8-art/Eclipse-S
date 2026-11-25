#if os(iOS)
import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
enum DownloadLiveActivityController {
    private struct PendingUpdate {
        let title: String
        let state: DownloadActivityAttributes.ContentState
        let generation: UInt64
    }

    private static var generationByDownloadID: [String: UInt64] = [:]
    private static var endedDownloadIDs: Set<String> = []
    private static var pendingUpdates: [String: PendingUpdate] = [:]
    private static var drainTasks: [String: Task<Void, Never>] = [:]

    private static func generation(for downloadID: String) -> UInt64 {
        generationByDownloadID[downloadID, default: 0]
    }

    static func prepare(downloadID: String) {
        generationByDownloadID[downloadID, default: 0] &+= 1
        endedDownloadIDs.remove(downloadID)
        pendingUpdates.removeValue(forKey: downloadID)
    }

    private static func activities(for downloadID: String) -> [Activity<DownloadActivityAttributes>] {
        Activity<DownloadActivityAttributes>.activities.filter {
            $0.attributes.downloadID == downloadID
        }
    }

    /// Keep only the newest state while an ActivityKit update is in flight.
    /// Lock Screen and Dynamic Island are two presentations of this same
    /// Activity; serializing writes prevents the two surfaces from receiving
    /// progress snapshots out of order.
    static func update(
        downloadID: String,
        title: String,
        progress: Double,
        completedBytes: Int64,
        totalBytes: Int64,
        status: String
    ) async {
        guard !endedDownloadIDs.contains(downloadID) else { return }
        let state = DownloadActivityAttributes.ContentState(
            progress: min(max(progress, 0), 1),
            completedBytes: max(0, completedBytes),
            totalBytes: max(0, totalBytes),
            status: String(status.prefix(80))
        )
        pendingUpdates[downloadID] = PendingUpdate(
            title: String(title.prefix(100)),
            state: state,
            generation: generation(for: downloadID)
        )

        guard drainTasks[downloadID] == nil else { return }
        let task = Task { @MainActor in
            await drainPendingUpdates(for: downloadID)
        }
        drainTasks[downloadID] = task
    }

    private static func drainPendingUpdates(for downloadID: String) async {
        defer {
            drainTasks.removeValue(forKey: downloadID)
            // An update can arrive after the loop observes an empty queue but
            // before this task releases its slot. In that window update() sees
            // an existing drain task and does not start another one. Re-arm the
            // drain after releasing the slot so the newest progress is never
            // stranded until the next network callback.
            if pendingUpdates[downloadID] != nil,
               !endedDownloadIDs.contains(downloadID) {
                let nextTask = Task { @MainActor in
                    await drainPendingUpdates(for: downloadID)
                }
                drainTasks[downloadID] = nextTask
            }
        }

        while let pending = pendingUpdates.removeValue(forKey: downloadID) {
            guard pending.generation == generation(for: downloadID),
                  !endedDownloadIDs.contains(downloadID) else { continue }

            let content = ActivityContent(
                state: pending.state,
                staleDate: Date().addingTimeInterval(15 * 60)
            )

            let currentActivities = activities(for: downloadID)
            if !currentActivities.isEmpty {
                // Repair any duplicate activities left by an interrupted prior
                // launch so every visible presentation receives the same state.
                for currentActivity in currentActivities {
                    await currentActivity.update(content)
                }
                continue
            }

            guard ActivityAuthorizationInfo().areActivitiesEnabled,
                  pending.generation == generation(for: downloadID),
                  !endedDownloadIDs.contains(downloadID) else { continue }

            do {
                _ = try Activity.request(
                    attributes: DownloadActivityAttributes(
                        downloadID: downloadID,
                        title: pending.title
                    ),
                    content: content,
                    pushType: nil
                )
            } catch {
                Logger.shared.log(
                    "Could not start download Live Activity: \(error.localizedDescription)",
                    type: "Download"
                )
            }
        }
    }

    static func end(downloadID: String, status: String) async {
        // Invalidate queued progress before waiting for an in-flight ActivityKit
        // write. This prevents an older update from overtaking the terminal state.
        generationByDownloadID[downloadID, default: 0] &+= 1
        endedDownloadIDs.insert(downloadID)
        pendingUpdates.removeValue(forKey: downloadID)

        if let drainTask = drainTasks[downloadID] {
            await drainTask.value
        }

        let matchingActivities = Activity<DownloadActivityAttributes>.activities.filter {
            $0.attributes.downloadID == downloadID
        }
        for activity in matchingActivities {
            let finalState = DownloadActivityAttributes.ContentState(
                progress: status == "Completed" ? 1 : activity.content.state.progress,
                completedBytes: activity.content.state.completedBytes,
                totalBytes: activity.content.state.totalBytes,
                status: String(status.prefix(80))
            )
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }
}
#endif
