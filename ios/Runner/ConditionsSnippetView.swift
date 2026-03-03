import SwiftUI

struct ConditionsSnippetView: View {
    let data: WidgetData
    let showStaleWarning: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Score + condition label
            HStack(spacing: 12) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(data.score) / 100.0)
                        .stroke(data.conditionColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)
                    Text("\(data.score)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(data.conditionColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(data.conditionLabel)
                        .font(.headline)
                        .foregroundColor(data.conditionColor)
                    Text(data.locationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Metrics row
            HStack(spacing: 16) {
                metricItem(icon: "water.waves", value: "\(data.waveHeight)ft")
                metricItem(icon: "wind", value: "\(data.windSpeed)mph \(data.windDir)")
                if !data.windContext.isEmpty {
                    Text(data.windContext)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(data.windContext == "offshore" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .cornerRadius(4)
                }
                Spacer()
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

    private func metricItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
