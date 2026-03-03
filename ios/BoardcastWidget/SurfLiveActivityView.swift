import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget Configuration

struct SurfLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SurfActivityAttributes.self) { context in
            // Lock Screen / Banner presentation
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    scoreView(score: context.state.score, label: context.state.conditionLabel)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "water.waves")
                                .font(.caption2)
                            Text("\(context.state.waveHeight)ft")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "wind")
                                .font(.caption2)
                            Text("\(context.state.windSpeed)mph \(context.state.windDir)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.state.bestWindowRange.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(conditionColor(context.state.bestWindowLabel))
                                Text(context.state.bestWindowRange)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(context.state.bestWindowLabel)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(context.attributes.locationName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                // Compact leading: score number
                Text("\(context.state.score)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(conditionColor(context.state.conditionLabel))
            } compactTrailing: {
                // Compact trailing: colored condition dot
                Circle()
                    .fill(conditionColor(context.state.conditionLabel))
                    .frame(width: 10, height: 10)
            } minimal: {
                // Minimal: score number only
                Text("\(context.state.score)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(conditionColor(context.state.conditionLabel))
            }
        }
    }

    private func scoreView(score: Int, label: String) -> some View {
        HStack(spacing: 6) {
            Text("\(score)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(conditionColor(label))
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(conditionColor(label))
        }
    }

    private func conditionColor(_ label: String) -> Color {
        switch label {
        case "Epic":  return Color(hex: "22c55e")
        case "Good":  return Color(hex: "4db8a4")
        case "Fair":  return Color(hex: "f59e0b")
        case "Poor":  return Color(hex: "ef4444")
        default:      return Color(hex: "4db8a4")
        }
    }
}

// MARK: - Lock Screen Banner View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<SurfActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: CGFloat(context.state.score) / 100.0)
                    .stroke(conditionColor(context.state.conditionLabel),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                Text("\(context.state.score)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(conditionColor(context.state.conditionLabel))
            }

            VStack(alignment: .leading, spacing: 3) {
                // Condition + location
                HStack(spacing: 6) {
                    Text(context.state.conditionLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(conditionColor(context.state.conditionLabel))
                    Text(context.attributes.locationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Wave + wind row
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "water.waves")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(context.state.waveHeight)ft")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "wind")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(context.state.windSpeed)mph \(context.state.windDir)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    if !context.state.windContext.isEmpty {
                        Text(context.state.windContext)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(context.state.windContext == "offshore"
                                        ? Color.green.opacity(0.15)
                                        : Color.orange.opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                // Best window callout
                if !context.state.bestWindowRange.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(conditionColor(context.state.bestWindowLabel))
                        Text(context.state.bestWindowRange)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(context.state.bestWindowLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Updated time
            VStack {
                Spacer()
                Text(updatedAgo)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }

    private var updatedAgo: String {
        let minutes = Int(Date().timeIntervalSince(context.state.updatedAt) / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }

    private func conditionColor(_ label: String) -> Color {
        switch label {
        case "Epic":  return Color(hex: "22c55e")
        case "Good":  return Color(hex: "4db8a4")
        case "Fair":  return Color(hex: "f59e0b")
        case "Poor":  return Color(hex: "ef4444")
        default:      return Color(hex: "4db8a4")
        }
    }
}
