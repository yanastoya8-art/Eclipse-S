import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct DownloadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: Double
        var completedBytes: Int64
        var totalBytes: Int64
        var status: String
    }

    var downloadID: String
    var title: String
}
