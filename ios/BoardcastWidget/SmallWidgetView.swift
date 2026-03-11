import SwiftUI
import WidgetKit

// MARK: - Small Widget (2×2) — Score Ring + Sparkline
//
// Design: Score ring dominates center with condition color.
// Bottom: micro-sparkline showing 6-hour score trend + best hour callout.

struct SmallWidgetView: View {
    let data: WidgetData

    // Brand colors
    private let navy = Color(hex: "0f1923")
    private let subText = Color(hex: "94a3b8")
    private let lightText = Color(hex: "e2e8f0")
    private let teal = Color(hex: "3d9189")  // sea-glass accent

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

            // Score ring (center) — larger with glow
            ScoreRing(score: data.score, color: data.conditionColor)
                .frame(width: 78, height: 78)
                .shadow(color: data.conditionColor.opacity(0.4), radius: 12)

            Spacer()

            // Micro-sparkline + best hour (bottom)
            if data.hourlyScores.count >= 2 {
                HStack(spacing: 6) {
                    MicroSparkline(scores: Array(data.hourlyScores.prefix(6)))
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)

                    if let best = bestHourLabel {
                        Text(best)
                            .font(.custom("DMMono-Medium", size: 10))
                            .foregroundColor(teal)
                    }
                }
                .padding(.bottom, 12)
                .padding(.horizontal, 14)
            } else {
                // Fallback: condition label
                Text(data.conditionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(data.conditionColor)
                    .padding(.bottom, 12)
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                navy
                // Condition color wash — Epic glows green, Poor glows red
                RadialGradient(
                    colors: [data.conditionColor.opacity(0.18), data.conditionColor.opacity(0.04)],
                    center: .center,
                    startRadius: 10,
                    endRadius: 120
                )
            }
        }
    }

    // MARK: - Helpers

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

    /// Best hour from first 6 entries
    private var bestHourLabel: String? {
        let subset = Array(data.hourlyScores.prefix(6))
        guard let best = subset.max(by: { $0.score < $1.score }) else { return nil }
        return formatHour(best.hour)
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 || hour == 12 { return hour == 0 ? "12a" : "12p" }
        if hour < 12 { return "\(hour)a" }
        return "\(hour - 12)p"
    }
}

// MARK: - Score Ring

struct ScoreRing: View {
    let score: Int
    let color: Color

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 5)

            // Filled arc
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Score number
            VStack(spacing: -2) {
                Text("\(score)")
                    .font(.custom("DMMono-Medium", size: 28))
                    .foregroundColor(Color(hex: "e2e8f0"))
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - Micro Sparkline

struct MicroSparkline: View {
    let scores: [WidgetData.HourlyScore]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = scores.count
            guard count >= 2 else { return AnyView(EmptyView()) }
            let step = w / CGFloat(count - 1)

            let values = scores.map { CGFloat($0.score) }
            let minVal = max(0, (values.min() ?? 0) - 10)
            let maxVal = min(100, (values.max() ?? 100) + 10)
            let range = max(maxVal - minVal, 1)

            return AnyView(
                ZStack {
                    // Area fill
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * step
                            let y = h * (1 - (v - minVal) / range)
                            if i == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                let px = CGFloat(i - 1) * step
                                let py = h * (1 - (values[i - 1] - minVal) / range)
                                path.addCurve(
                                    to: CGPoint(x: x, y: y),
                                    control1: CGPoint(x: px + step * 0.4, y: py),
                                    control2: CGPoint(x: x - step * 0.4, y: y)
                                )
                            }
                        }
                        path.addLine(to: CGPoint(x: CGFloat(count - 1) * step, y: h))
                        path.closeSubpath()
                    }
                    .fill(Color(hex: "3d9189").opacity(0.25))

                    // Line
                    Path { path in
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * step
                            let y = h * (1 - (v - minVal) / range)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                let px = CGFloat(i - 1) * step
                                let py = h * (1 - (values[i - 1] - minVal) / range)
                                path.addCurve(
                                    to: CGPoint(x: x, y: y),
                                    control1: CGPoint(x: px + step * 0.4, y: py),
                                    control2: CGPoint(x: x - step * 0.4, y: y)
                                )
                            }
                        }
                    }
                    .stroke(Color(hex: "3d9189"), lineWidth: 1.5)
                }
            )
        }
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
