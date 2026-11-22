import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
@main
struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.tint)
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.monospacedDigit())
                }
                ProgressView(value: context.state.progress)
                HStack {
                    Text(context.state.status)
                    Spacer()
                    if context.state.totalBytes > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: context.state.completedBytes, countStyle: .file))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.82))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.down.circle.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.attributes.title).font(.caption).lineLimit(1)
                        ProgressView(value: context.state.progress)
                        Text(context.state.status).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "arrow.down.circle.fill")
            } compactTrailing: {
                Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "arrow.down.circle.fill")
            }
        }
    }
}
