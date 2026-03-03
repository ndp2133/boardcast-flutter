import SwiftUI
import WidgetKit

// MARK: - Lock Screen Widget — Rectangular + Circular
//
// Rectangular: two-line summary (score + label, wave + wind).
// Circular: score gauge.
// Lock screen renders in monochrome "vibrant" mode — no custom colors.

struct LockScreenRectangularView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Line 1: score + condition
            HStack(spacing: 4) {
                Text("\(data.score)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                Text(data.conditionLabel)
                    .font(.system(size: 13, weight: .medium))
            }

            // Line 2: wave + wind summary
            HStack(spacing: 4) {
                Image(systemName: "water.waves")
                    .font(.system(size: 10))
                Text("\(data.waveHeight)ft")
                    .font(.system(size: 12, design: .monospaced))
                Text("·")
                    .font(.system(size: 10))
                Image(systemName: "wind")
                    .font(.system(size: 10))
                Text("\(data.windSpeed)mph \(data.windDir)")
                    .font(.system(size: 12, design: .monospaced))
            }
            .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Circular Gauge

struct LockScreenCircularView: View {
    let data: WidgetData

    var body: some View {
        Gauge(value: Double(data.score), in: 0...100) {
            Text("Surf")
                .font(.system(size: 8))
        } currentValueLabel: {
            Text("\(data.score)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Previews

#if DEBUG
struct LockScreenRectangular_Previews: PreviewProvider {
    static var previews: some View {
        LockScreenRectangularView(data: .placeholder)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}

struct LockScreenCircular_Previews: PreviewProvider {
    static var previews: some View {
        LockScreenCircularView(data: .placeholder)
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}
#endif
