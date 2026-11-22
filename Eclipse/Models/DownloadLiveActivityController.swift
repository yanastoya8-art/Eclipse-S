#if os(iOS)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
@MainActor
enum DownloadLiveActivityController {
    private static var activities: [String: Activity<DownloadActivityAttributes>] {
        Dictionary(
            uniqueKeysWithValues: Activity<DownloadActivityAttributes>.activities.map {
                ($0.attributes.downloadID, $0)
            }
        )
    }

    static func update(
        downloadID: String,
        title: String,
        progress: Double,
        completedBytes: Int64,
        totalBytes: Int64,
        status: String
    ) async {
        let boundedProgress = min(max(progress, 0), 1)
        let state = DownloadActivityAttributes.ContentState(
            progress: boundedProgress,
            completedBytes: max(0, completedBytes),
            totalBytes: max(0, totalBytes),
            status: String(status.prefix(80))
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))
        if let activity = activities[downloadID] {
            await activity.update(content)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = DownloadActivityAttributes(downloadID: downloadID, title: String(title.prefix(100)))
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            Logger.shared.log("Could not start download Live Activity: \(error.localizedDescription)", type: "Download")
        }
    }

    static func end(downloadID: String, status: String) async {
        guard let activity = activities[downloadID] else { return }
        let finalState = DownloadActivityAttributes.ContentState(
            progress: status == "Completed" ? 1 : activity.content.state.progress,
            completedBytes: activity.content.state.completedBytes,
            totalBytes: activity.content.state.totalBytes,
            status: String(status.prefix(80))
        )
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(5))
        )
    }
}
#endif
