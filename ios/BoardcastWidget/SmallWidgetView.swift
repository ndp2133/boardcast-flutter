import SwiftUI
import WidgetKit

// MARK: - Small Widget (2×2) — Score at a Glance
//
// Design: Score number dominates. Condition color tint background.
// Bottom: compact wave + wind metrics.

struct SmallWidgetView: View {
    let data: WidgetData

    // Brand colors
    private let navy = Color(hex: "0f1923")
    private let subText = Color(hex: "94a3b8")
    private let lightText = Color(hex: "e2e8f0")

    var body: some View {
        VStack(spacing: 0) {
            // Location name (top)
            HStack {
                Text(shortLocationName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(subText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 14)

            Spacer()

            // Score number (center, dominant)
            Text("\(data.score)")
                .font(.custom("DMMono-Medium", size: 42))
                .foregroundColor(lightText)
                .minimumScaleFactor(0.7)

            // Condition label
            Text(data.conditionLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(data.conditionColor)

            Spacer()

            // Wave + wind (bottom)
            HStack(spacing: 10) {
                metricLabel(icon: "water.waves", value: "\(data.waveHeight)ft")
                metricLabel(icon: "wind", value: "\(data.windSpeed)mph")
            }
            .padding(.bottom, 12)
            .padding(.horizontal, 14)
        }
        .containerBackground(for: .widget) {
            ZStack {
                navy
                data.conditionColor.opacity(0.12)
            }
        }
    }

    // MARK: - Helpers

    private func metricLabel(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(subText)
            Text(value)
                .font(.custom("DMMono-Medium", size: 11))
                .foregroundColor(lightText)
        }
    }

    /// Shorten "Rockaway Beach, NY" → "Rockaway"
    private var shortLocationName: String {
        let name = data.locationName
        if let comma = name.firstIndex(of: ",") {
            let beforeComma = String(name[name.startIndex..<comma])
            return beforeComma
                .replacingOccurrences(of: " Beach", with: "")
                .replacingOccurrences(of: " Point", with: " Pt")
        }
        return name
    }
}

// MARK: - Preview

#if DEBUG
struct SmallWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        SmallWidgetView(data: .placeholder)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
