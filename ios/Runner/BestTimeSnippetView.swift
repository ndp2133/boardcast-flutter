import SwiftUI

struct BestTimeSnippetView: View {
    let data: WidgetData
    let timeRange: String?
    let showStaleWarning: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Location caption
            Text(data.locationName)
                .font(.caption)
                .foregroundColor(.secondary)

            if let range = timeRange {
                // Best window time range
                Text(range)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(windowColor)

                // Condition label + score
                HStack(spacing: 6) {
                    Text(data.bestWindowLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(windowColor)
                    Text("(\(data.bestWindowScore))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Best window label
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(windowColor)
                    Text("Best window")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // No standout window
                Image(systemName: "cloud.sun")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                Text("No standout window today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if showStaleWarning {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.caption2)
                    Text("Data is over 1hr old")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
        }
        .padding(12)
    }

    private var windowColor: Color {
        switch data.bestWindowLabel {
        case "Epic":  return Color(hex: "22c55e")
        case "Good":  return Color(hex: "4db8a4")
        case "Fair":  return Color(hex: "f59e0b")
        case "Poor":  return Color(hex: "ef4444")
        default:      return Color(hex: "4db8a4")
        }
    }
}
