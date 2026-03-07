import WidgetKit
import SwiftUI

// MARK: - Watch Complication Data

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let score: Int
    let conditionLabel: String
    let locationName: String
    let waveHeight: String
    let windSpeed: String

    var conditionColor: Color {
        switch conditionLabel {
        case "Epic":  return Color(red: 34/255, green: 197/255, blue: 94/255)
        case "Good":  return Color(red: 77/255, green: 184/255, blue: 164/255)
        case "Fair":  return Color(red: 245/255, green: 158/255, blue: 11/255)
        case "Poor":  return Color(red: 239/255, green: 68/255, blue: 68/255)
        default:      return Color(red: 77/255, green: 184/255, blue: 164/255)
        }
    }

    static let placeholder = WatchComplicationEntry(
        date: Date(),
        score: 74,
        conditionLabel: "Good",
        locationName: "Rockaway",
        waveHeight: "3.2",
        windSpeed: "8"
    )
}

// MARK: - Timeline Provider

struct WatchComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchComplicationEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchComplicationEntry) -> Void) {
        completion(context.isPreview ? .placeholder : readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchComplicationEntry>) -> Void) {
        let entry = readEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> WatchComplicationEntry {
        let d = UserDefaults.standard
        return WatchComplicationEntry(
            date: Date(),
            score: d.integer(forKey: "watch_score"),
            conditionLabel: d.string(forKey: "watch_conditionLabel") ?? "—",
            locationName: d.string(forKey: "watch_locationName") ?? "Boardcast",
            waveHeight: d.string(forKey: "watch_waveHeight") ?? "--",
            windSpeed: d.string(forKey: "watch_windSpeed") ?? "--"
        )
    }
}

// MARK: - Widget Bundle

@main
struct BoardcastWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        CircularComplication()
        RectangularComplication()
        InlineComplication()
        CornerComplication()
    }
}

// MARK: - Circular Complication (the Lumy play — score gauge on watch face)

struct CircularComplication: Widget {
    let kind = "BoardcastWatchCircular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            ZStack {
                AccessoryWidgetBackground()
                Gauge(value: Double(entry.score), in: 0...100) {
                    Text("Surf")
                        .font(.system(size: 7))
                } currentValueLabel: {
                    Text("\(entry.score)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                }
                .gaugeStyle(.accessoryCircular)
                .tint(entry.conditionColor)
            }
            .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Surf Score")
        .description("Your personalized surf score at a glance.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Rectangular Complication (score + location + conditions)

struct RectangularComplication: Widget {
    let kind = "BoardcastWatchRectangular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(entry.score)")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                    Text(entry.conditionLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(entry.conditionColor)
                }

                Text(shortName(entry.locationName))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "water.waves")
                        .font(.system(size: 9))
                    Text("\(entry.waveHeight)ft")
                        .font(.system(size: 11, design: .monospaced))
                    Text("\u{00b7}")
                        .font(.system(size: 9))
                    Image(systemName: "wind")
                        .font(.system(size: 9))
                    Text("\(entry.windSpeed)mph")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
            .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Surf Conditions")
        .description("Score, location, and current conditions.")
        .supportedFamilies([.accessoryRectangular])
    }

    private func shortName(_ name: String) -> String {
        if let comma = name.firstIndex(of: ",") {
            return String(name[name.startIndex..<comma])
                .replacingOccurrences(of: " Beach", with: "")
        }
        return name
    }
}

// MARK: - Inline Complication (single line of text)

struct InlineComplication: Widget {
    let kind = "BoardcastWatchInline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            Text("\(entry.score) \(entry.conditionLabel) \u{00b7} \(entry.waveHeight)ft")
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Surf Score Inline")
        .description("Score and conditions in a single line.")
        .supportedFamilies([.accessoryInline])
    }
}

// MARK: - Corner Complication (score number with gauge arc)

struct CornerComplication: Widget {
    let kind = "BoardcastWatchCorner"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationProvider()) { entry in
            ZStack {
                AccessoryWidgetBackground()
                Text("\(entry.score)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .widgetLabel {
                        Gauge(value: Double(entry.score), in: 0...100) {
                            Text("Surf")
                        }
                        .tint(entry.conditionColor)
                        .gaugeStyle(.accessoryLinear)
                    }
            }
            .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Surf Score Corner")
        .description("Score with gauge arc in the corner.")
        .supportedFamilies([.accessoryCorner])
    }
}

// MARK: - Previews

#if DEBUG
struct CircularComplication_Previews: PreviewProvider {
    static var previews: some View {
        CircularComplication()
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}

struct RectangularComplication_Previews: PreviewProvider {
    static var previews: some View {
        RectangularComplication()
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
#endif
