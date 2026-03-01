import SwiftUI
import WidgetKit

// MARK: - Medium Widget (4×2) — "The Window"
//
// Design: Score area-fill timeline showing when to surf.
// Peaks = good conditions. Shape IS the information.
// On-brand: teal accent, DM Mono numbers, condition color ladder.

struct MediumWidgetView: View {
    let data: WidgetData

    // Brand colors
    private let teal = Color(hex: "4db8a4")
    private let epic = Color(hex: "22c55e")
    private let good = Color(hex: "4db8a4")
    private let fair = Color(hex: "f59e0b")
    private let poor = Color(hex: "ef4444")

    var body: some View {
        VStack(spacing: 0) {
            // -- Top bar: location + score --
            headerRow
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            // -- Score fill timeline --
            if !data.hourlyScores.isEmpty {
                ScoreFillChart(scores: data.hourlyScores, bestStart: data.bestWindowStart, bestEnd: data.bestWindowEnd)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .padding(.horizontal, 10)
            }

            Spacer(minLength: 2)

            // -- Bottom: current conditions + best window --
            bottomRow
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .containerBackground(for: .widget) {
            Color(hex: "0f1923") // midnight navy — always dark for widget
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(shortLocationName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "94a3b8"))
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                Text(data.conditionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(data.conditionColor)

                Text("·")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "94a3b8"))

                Text("\(data.score)")
                    .font(.custom("DMMono-Medium", size: 16))
                    .foregroundColor(Color(hex: "e2e8f0"))
            }
        }
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack(alignment: .center, spacing: 0) {
            // Current conditions
            HStack(spacing: 10) {
                conditionPill(icon: "water.waves", value: "\(data.waveHeight)ft")
                conditionPill(icon: "wind", value: "\(data.windSpeed)mph")
                if !data.windContext.isEmpty {
                    Text(data.windContext)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(
                            data.windContext == "offshore" ? epic :
                            data.windContext == "onshore" ? poor : fair
                        )
                }
            }

            Spacer()

            // Best window callout
            if let timeRange = data.bestWindowTimeRange {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(teal)
                    Text(timeRange)
                        .font(.custom("DMMono-Medium", size: 11))
                        .foregroundColor(teal)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(teal.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Helpers

    private func conditionPill(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "94a3b8"))
            Text(value)
                .font(.custom("DMMono-Medium", size: 11))
                .foregroundColor(Color(hex: "e2e8f0"))
        }
    }

    /// Shorten "Rockaway Beach, NY" → "Rockaway"
    private var shortLocationName: String {
        let name = data.locationName
        if let comma = name.firstIndex(of: ",") {
            let beforeComma = String(name[name.startIndex..<comma])
            // Drop "Beach", "Point", etc. for widget brevity
            return beforeComma
                .replacingOccurrences(of: " Beach", with: "")
                .replacingOccurrences(of: " Point", with: " Pt")
        }
        return name
    }
}

// MARK: - Score Fill Chart

/// Area-fill chart where height = match score and fill color transitions
/// through the condition ladder. Peaks are when to go.
struct ScoreFillChart: View {
    let scores: [WidgetData.HourlyScore]
    let bestStart: String
    let bestEnd: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let chartH = h - 12 // leave room for time labels
            let count = scores.count
            guard count > 1 else { return AnyView(EmptyView()) }
            let step = w / CGFloat(count - 1)

            return AnyView(
                ZStack(alignment: .top) {
                    // Area fill with gradient
                    scoreFillPath(width: w, height: chartH, step: step)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4db8a4").opacity(0.6), Color(hex: "4db8a4").opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Condition-colored line on top
                    scoreLinePath(width: w, height: chartH, step: step)
                        .stroke(
                            LinearGradient(
                                colors: lineGradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )

                    // Best window indicator
                    bestWindowOverlay(width: w, height: chartH, step: step)

                    // Time labels along the bottom
                    timeLabels(width: w, height: h, step: step)
                }
            )
        }
    }

    // MARK: - Paths

    private func yForScore(_ score: Int, height: CGFloat) -> CGFloat {
        let normalized = CGFloat(score) / 100.0
        return height * (1 - normalized)
    }

    private func scoreFillPath(width: CGFloat, height: CGFloat, step: CGFloat) -> Path {
        Path { path in
            // Start at bottom-left
            path.move(to: CGPoint(x: 0, y: height))

            // Build curve through score points
            for (i, entry) in scores.enumerated() {
                let x = CGFloat(i) * step
                let y = yForScore(entry.score, height: height)

                if i == 0 {
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    let prevX = CGFloat(i - 1) * step
                    let prevY = yForScore(scores[i - 1].score, height: height)
                    let cx1 = prevX + step * 0.4
                    let cx2 = x - step * 0.4
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: cx1, y: prevY),
                        control2: CGPoint(x: cx2, y: y)
                    )
                }
            }

            // Close at bottom-right
            path.addLine(to: CGPoint(x: CGFloat(scores.count - 1) * step, y: height))
            path.closeSubpath()
        }
    }

    private func scoreLinePath(width: CGFloat, height: CGFloat, step: CGFloat) -> Path {
        Path { path in
            for (i, entry) in scores.enumerated() {
                let x = CGFloat(i) * step
                let y = yForScore(entry.score, height: height)

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    let prevX = CGFloat(i - 1) * step
                    let prevY = yForScore(scores[i - 1].score, height: height)
                    let cx1 = prevX + step * 0.4
                    let cx2 = x - step * 0.4
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: cx1, y: prevY),
                        control2: CGPoint(x: cx2, y: y)
                    )
                }
            }
        }
    }

    // MARK: - Gradient Colors

    /// Build per-segment colors based on each hour's condition
    private var lineGradientColors: [Color] {
        scores.map { entry in
            switch entry.condition {
            case 0:  return Color(hex: "22c55e")  // epic
            case 1:  return Color(hex: "4db8a4")  // good
            case 2:  return Color(hex: "f59e0b")  // fair
            default: return Color(hex: "ef4444")  // poor
            }
        }
    }

    // MARK: - Best Window Overlay

    private func bestWindowOverlay(width: CGFloat, height: CGFloat, step: CGFloat) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        guard !bestStart.isEmpty,
              let startDate = formatter.date(from: bestStart),
              let endDate = formatter.date(from: bestEnd) else {
            return AnyView(EmptyView())
        }

        let startHour = Calendar.current.component(.hour, from: startDate)
        let endHour = Calendar.current.component(.hour, from: endDate)

        // Find matching indices
        guard let startIdx = scores.firstIndex(where: { $0.hour == startHour }),
              let endIdx = scores.lastIndex(where: { $0.hour == endHour }),
              startIdx <= endIdx else {
            return AnyView(EmptyView())
        }

        let x1 = CGFloat(startIdx) * step
        let x2 = CGFloat(endIdx) * step

        return AnyView(
            Rectangle()
                .fill(Color(hex: "4db8a4").opacity(0.12))
                .frame(width: x2 - x1, height: height)
                .offset(x: x1)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }

    // MARK: - Time Labels

    private func timeLabels(width: CGFloat, height: CGFloat, step: CGFloat) -> some View {
        let labelIndices = stride(from: 0, to: scores.count, by: max(1, scores.count / 6))

        return ZStack {
            ForEach(Array(labelIndices), id: \.self) { i in
                if i < scores.count {
                    Text(formatHour(scores[i].hour))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(hex: "94a3b8").opacity(0.7))
                        .position(
                            x: CGFloat(i) * step,
                            y: height - 3
                        )
                }
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 || hour == 12 { return hour == 0 ? "12a" : "12p" }
        if hour < 12 { return "\(hour)a" }
        return "\(hour - 12)p"
    }
}

// MARK: - Preview

#if DEBUG
struct MediumWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        MediumWidgetView(data: .placeholder)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif
