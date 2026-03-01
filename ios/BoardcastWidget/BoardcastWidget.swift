import WidgetKit
import SwiftUI

// MARK: - Data Model

struct WidgetData {
    let score: Int                    // 0-100
    let conditionLabel: String        // "Epic", "Good", "Fair", "Poor"
    let locationName: String
    let waveHeight: String            // "3.2" (ft)
    let windSpeed: String             // "12" (mph)
    let windDir: String               // "NW"
    let windContext: String            // "offshore", "onshore", "cross"
    let fetchedAt: Date?
    let hourlyScores: [HourlyScore]   // 18hr timeline
    let bestWindowStart: String       // ISO 8601 or empty
    let bestWindowEnd: String
    let bestWindowScore: Int
    let bestWindowLabel: String

    struct HourlyScore: Identifiable {
        let id: Int  // index
        let hour: Int
        let score: Int      // 0-100
        let condition: Int  // 0=epic, 1=good, 2=fair, 3=poor
    }

    var conditionColor: Color {
        switch conditionLabel {
        case "Epic":  return Color(hex: "22c55e")
        case "Good":  return Color(hex: "4db8a4")
        case "Fair":  return Color(hex: "f59e0b")
        case "Poor":  return Color(hex: "ef4444")
        default:      return Color(hex: "4db8a4")
        }
    }

    var bestWindowTimeRange: String? {
        guard !bestWindowStart.isEmpty, !bestWindowEnd.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        guard let start = formatter.date(from: bestWindowStart),
              let end = formatter.date(from: bestWindowEnd) else { return nil }

        let display = DateFormatter()
        display.dateFormat = "ha"
        display.amSymbol = "am"
        display.pmSymbol = "pm"

        let startStr = display.string(from: start).lowercased()
        let endStr = display.string(from: end).lowercased()
        return "\(startStr)–\(endStr)"
    }

    var dataAge: String? {
        guard let fetched = fetchedAt else { return nil }
        let minutes = Int(Date().timeIntervalSince(fetched) / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }

    static let placeholder = WidgetData(
        score: 74,
        conditionLabel: "Good",
        locationName: "Rockaway Beach, NY",
        waveHeight: "3.2",
        windSpeed: "8",
        windDir: "NW",
        windContext: "offshore",
        fetchedAt: Date(),
        hourlyScores: (0..<18).map { i in
            HourlyScore(
                id: i,
                hour: (6 + i) % 24,
                score: max(0, min(100, 40 + Int.random(in: -20...40))),
                condition: i < 6 ? 1 : i < 12 ? 2 : 3
            )
        },
        bestWindowStart: "",
        bestWindowEnd: "",
        bestWindowScore: 78,
        bestWindowLabel: "Good"
    )
}

// MARK: - UserDefaults Reader

extension WidgetData {
    static func read() -> WidgetData {
        let defaults = UserDefaults(suiteName: "group.com.boardcast.boardcastFlutter")

        let score = defaults?.integer(forKey: "score") ?? 0
        let conditionLabel = defaults?.string(forKey: "conditionLabel") ?? "Poor"
        let locationName = defaults?.string(forKey: "locationName") ?? "No location"
        let waveHeight = defaults?.string(forKey: "waveHeight") ?? "--"
        let windSpeed = defaults?.string(forKey: "windSpeed") ?? "--"
        let windDir = defaults?.string(forKey: "windDir") ?? "--"
        let windContext = defaults?.string(forKey: "windContext") ?? ""
        let fetchedAtStr = defaults?.string(forKey: "fetchedAt") ?? ""
        let hourlyJson = defaults?.string(forKey: "hourlyScores") ?? "[]"
        let bestStart = defaults?.string(forKey: "bestWindowStart") ?? ""
        let bestEnd = defaults?.string(forKey: "bestWindowEnd") ?? ""
        let bestScore = defaults?.integer(forKey: "bestWindowScore") ?? 0
        let bestLabel = defaults?.string(forKey: "bestWindowLabel") ?? ""

        // Parse fetchedAt
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fetchedAt = isoFormatter.date(from: fetchedAtStr)

        // Parse hourly scores JSON
        var hourlyScores: [HourlyScore] = []
        if let data = hourlyJson.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            hourlyScores = arr.enumerated().map { (i, obj) in
                HourlyScore(
                    id: i,
                    hour: obj["h"] as? Int ?? 0,
                    score: obj["s"] as? Int ?? 0,
                    condition: obj["c"] as? Int ?? 3
                )
            }
        }

        return WidgetData(
            score: score,
            conditionLabel: conditionLabel,
            locationName: locationName,
            waveHeight: waveHeight,
            windSpeed: windSpeed,
            windDir: windDir,
            windContext: windContext,
            fetchedAt: fetchedAt,
            hourlyScores: hourlyScores,
            bestWindowStart: bestStart,
            bestWindowEnd: bestEnd,
            bestWindowScore: bestScore,
            bestWindowLabel: bestLabel
        )
    }
}

// MARK: - Timeline Provider

struct BoardcastEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct BoardcastTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardcastEntry {
        BoardcastEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BoardcastEntry) -> Void) {
        if context.isPreview {
            completion(BoardcastEntry(date: Date(), data: .placeholder))
        } else {
            completion(BoardcastEntry(date: Date(), data: .read()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardcastEntry>) -> Void) {
        let entry = BoardcastEntry(date: Date(), data: .read())
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
