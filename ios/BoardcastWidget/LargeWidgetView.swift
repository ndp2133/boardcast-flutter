import SwiftUI
import WidgetKit

// MARK: - Large Widget (4×4) — Full Dashboard
//
// Layout (top→bottom):
// 1. Header: location + score + condition label
// 2. Score fill timeline (reuses ScoreFillChart)
// 3. Wave + tide chart (wave bars + tide curve)
// 4. Best window card (teal-washed)
// 5. Upcoming windows (2-3 rows)

struct LargeWidgetView: View {
    let data: WidgetData

    private let navy = Color(hex: "0f1923")
    private let teal = Color(hex: "4db8a4")
    private let subText = Color(hex: "94a3b8")
    private let lightText = Color(hex: "e2e8f0")

    var body: some View {
        VStack(spacing: 0) {
            // 1. Header
            headerRow
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            // 2. Score fill timeline
            if !data.hourlyScores.isEmpty {
                ScoreFillChart(
                    scores: data.hourlyScores,
                    bestStart: data.bestWindowStart,
                    bestEnd: data.bestWindowEnd
                )
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 4)

            // 3. Wave + tide chart
            if !data.hourlyWaveHeights.isEmpty {
                WaveTideChart(
                    waves: data.hourlyWaveHeights,
                    tides: data.hourlyTideHeights
                )
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 4)

            // 4. Best window card
            if let timeRange = data.bestWindowTimeRange {
                bestWindowCard(timeRange: timeRange)
                    .padding(.horizontal, 14)
            }

            Spacer(minLength: 4)

            // 5. Upcoming windows
            if !data.upcomingWindows.isEmpty {
                upcomingWindowsList
                    .padding(.horizontal, 14)
            }

            Spacer(minLength: 6)
        }
        .containerBackground(for: .widget) {
            navy
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(shortLocationName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(subText)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                Text(data.conditionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(data.conditionColor)

                Text("·")
                    .font(.system(size: 12))
                    .foregroundColor(subText)

                Text("\(data.score)")
                    .font(.custom("DMMono-Medium", size: 16))
                    .foregroundColor(lightText)
            }
        }
    }

    // MARK: - Best Window Card

    private func bestWindowCard(timeRange: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(teal)

            VStack(alignment: .leading, spacing: 1) {
                Text("Best Window")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(subText)
                Text(timeRange)
                    .font(.custom("DMMono-Medium", size: 14))
                    .foregroundColor(lightText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(data.bestWindowLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(data.conditionColor)
                Text("\(data.bestWindowScore)")
                    .font(.custom("DMMono-Medium", size: 12))
                    .foregroundColor(subText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(teal.opacity(0.1))
        )
    }

    // MARK: - Upcoming Windows

    private var upcomingWindowsList: some View {
        VStack(spacing: 4) {
            ForEach(data.upcomingWindows.prefix(3)) { window in
                HStack(spacing: 6) {
                    Text(window.dayLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(subText)
                        .frame(width: 55, alignment: .leading)

                    if let range = window.timeRange {
                        Text(range)
                            .font(.custom("DMMono-Medium", size: 10))
                            .foregroundColor(lightText)
                    }

                    Spacer()

                    if let wave = window.waveHeight {
                        Text("\(String(format: "%.1f", wave))ft")
                            .font(.custom("DMMono-Medium", size: 10))
                            .foregroundColor(subText)
                    }

                    Text(window.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(window.conditionColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(window.conditionColor.opacity(0.15))
                        )
                }
            }
        }
    }

    // MARK: - Helpers

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

// MARK: - Wave + Tide Chart

struct WaveTideChart: View {
    let waves: [WidgetData.HourlyWave]
    let tides: [WidgetData.HourlyTide]

    private let teal = Color(hex: "4db8a4")
    private let tideLine = Color(hex: "94a3b8")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = waves.count
            guard count > 1 else { return AnyView(EmptyView()) }
            let step = w / CGFloat(count)
            let barWidth = max(step * 0.5, 3)

            // Wave range
            let waveValues = waves.compactMap { $0.waveHeight }
            let maxWave = max(waveValues.max() ?? 1, 1)

            return AnyView(
                ZStack(alignment: .bottom) {
                    // Wave bars
                    HStack(alignment: .bottom, spacing: step - barWidth) {
                        ForEach(waves) { wave in
                            let wh = wave.waveHeight ?? 0
                            let barH = max(CGFloat(wh / maxWave) * (h * 0.85), 2)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(teal.opacity(0.6))
                                .frame(width: barWidth, height: barH)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Tide curve overlay
                    if !tides.isEmpty {
                        tideCurvePath(width: w, height: h)
                            .stroke(tideLine.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    }
                }
            )
        }
    }

    private func tideCurvePath(width: CGFloat, height: CGFloat) -> Path {
        let tideValues = tides.compactMap { $0.tideHeight }
        guard tideValues.count >= 2 else { return Path() }

        let minTide = tideValues.min() ?? 0
        let maxTide = max((tideValues.max() ?? 1) - minTide, 0.1)
        let step = width / CGFloat(tides.count - 1)

        return Path { path in
            for (i, tide) in tides.enumerated() {
                let t = tide.tideHeight ?? minTide
                let x = CGFloat(i) * step
                let y = height * (1 - CGFloat(t - minTide) / CGFloat(maxTide)) * 0.85

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    let px = CGFloat(i - 1) * step
                    let prevT = tides[i - 1].tideHeight ?? minTide
                    let py = height * (1 - CGFloat(prevT - minTide) / CGFloat(maxTide)) * 0.85
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: px + step * 0.4, y: py),
                        control2: CGPoint(x: x - step * 0.4, y: y)
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LargeWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        LargeWidgetView(data: .placeholder)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
#endif
