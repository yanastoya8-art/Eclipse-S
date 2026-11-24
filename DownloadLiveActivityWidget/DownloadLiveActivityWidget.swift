import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.2, *)
@main
struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: statusSymbol(for: context.state.status))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(statusTint(for: context.state.status))
                        .frame(width: 34, height: 34)
                        .background(statusTint(for: context.state.status).opacity(0.16), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                }

                ProgressView(value: context.state.progress)
                    .tint(statusTint(for: context.state.status))
                    .scaleEffect(x: 1, y: 1.35, anchor: .center)

                HStack(alignment: .firstTextBaseline) {
                    Label(
                        context.state.totalBytes > 0
                            ? ByteCountFormatter.string(fromByteCount: context.state.completedBytes, countStyle: .file)
                            : ByteCountFormatter.string(fromByteCount: context.state.completedBytes, countStyle: .file),
                        systemImage: "arrow.down.to.line"
                    )
                    Spacer()
                    if context.state.totalBytes > 0 {
                        Text("of " + ByteCountFormatter.string(fromByteCount: context.state.totalBytes, countStyle: .file))
                    } else {
                        Text("Size unavailable")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(URL(string: "luna://open/tab/downloads"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: statusSymbol(for: context.state.status))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(statusTint(for: context.state.status))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.status)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(context.attributes.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        ProgressView(value: context.state.progress)
                            .tint(statusTint(for: context.state.status))
                        HStack {
                            Text(ByteCountFormatter.string(fromByteCount: context.state.completedBytes, countStyle: .file))
                            Spacer()
                            if context.state.totalBytes > 0 {
                                Text("of " + ByteCountFormatter.string(fromByteCount: context.state.totalBytes, countStyle: .file))
                            } else {
                                Text("Downloading")
                            }
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: statusSymbol(for: context.state.status))
                    .foregroundStyle(statusTint(for: context.state.status))
            } compactTrailing: {
                Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2.monospacedDigit())
                    .contentTransition(.numericText())
            } minimal: {
                Image(systemName: statusSymbol(for: context.state.status))
                    .foregroundStyle(statusTint(for: context.state.status))
            }
            .widgetURL(URL(string: "luna://open/tab/downloads"))
            .keylineTint(statusTint(for: context.state.status))
        }
    }

    private func statusSymbol(for status: String) -> String {
        switch status.lowercased() {
        case "completed": return "checkmark.circle.fill"
        case "paused", "queued", "waiting": return "pause.circle.fill"
        case "failed", "error": return "exclamationmark.circle.fill"
        case "cancelled", "canceled": return "xmark.circle.fill"
        default: return "arrow.down.circle.fill"
        }
    }

    private func statusTint(for status: String) -> Color {
        switch status.lowercased() {
        case "completed": return .green
        case "paused", "queued", "waiting": return .orange
        case "failed", "error", "cancelled", "canceled": return .red
        default: return .mint
        }
    }
}
