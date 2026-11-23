#if os(iOS)
import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
enum DownloadLiveActivityController {
    private static var startingDownloadIDs: Set<String> = []
    private static var generationByDownloadID: [String: UInt64] = [:]
    private static var endedDownloadIDs: Set<String> = []

    private static func generation(for downloadID: String) -> UInt64 {
        generationByDownloadID[downloadID, default: 0]
    }

    static func prepare(downloadID: String) {
        generationByDownloadID[downloadID, default: 0] &+= 1
        endedDownloadIDs.remove(downloadID)
    }

    private static func activity(for downloadID: String) -> Activity<DownloadActivityAttributes>? {
        Activity<DownloadActivityAttributes>.activities.first {
            $0.attributes.downloadID == downloadID
        }
    }

    static func update(
        downloadID: String,
        title: String,
        progress: Double,
        completedBytes: Int64,
        totalBytes: Int64,
        status: String
    ) async {
        // A late progress callback must never recreate an activity after the
        // corresponding download has been removed or cancelled.
        guard !endedDownloadIDs.contains(downloadID) else { return }
        let generation = generation(for: downloadID)
        let boundedProgress = min(max(progress, 0), 1)
        let state = DownloadActivityAttributes.ContentState(
            progress: boundedProgress,
            completedBytes: max(0, completedBytes),
            totalBytes: max(0, totalBytes),
            status: String(status.prefix(80))
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))
        if let activity = activity(for: downloadID) {
            await activity.update(content)
            guard generation(for: downloadID) == generation,
                  !endedDownloadIDs.contains(downloadID) else { return }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              !startingDownloadIDs.contains(downloadID) else { return }
        startingDownloadIDs.insert(downloadID)
        defer { startingDownloadIDs.remove(downloadID) }
        // A previous request may have completed while this update was queued.
        guard generation(for: downloadID) == generation,
              !endedDownloadIDs.contains(downloadID) else { return }
        if let activity = activity(for: downloadID) {
            await activity.update(content)
            guard generation(for: downloadID) == generation,
                  !endedDownloadIDs.contains(downloadID) else { return }
            return
        }
        let attributes = DownloadActivityAttributes(downloadID: downloadID, title: String(title.prefix(100)))
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            guard generation(for: downloadID) == generation,
                  !endedDownloadIDs.contains(downloadID) else {
                if let staleActivity = activity(for: downloadID) {
                    await staleActivity.end(nil, dismissalPolicy: .immediate)
                }
                return
            }
        } catch {
            Logger.shared.log("Could not start download Live Activity: \(error.localizedDescription)", type: "Download")
        }
    }

    static func end(downloadID: String, status: String) async {
        // Invalidate all progress updates already queued on the main actor before
        // ending every matching activity. Immediate dismissal prevents a deleted
        // download from lingering in the Dynamic Island or Lock Screen.
        generationByDownloadID[downloadID, default: 0] &+= 1
        endedDownloadIDs.insert(downloadID)
        startingDownloadIDs.remove(downloadID)
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
