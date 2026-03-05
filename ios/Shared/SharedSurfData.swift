import SwiftUI

// MARK: - Shared Data Model (Runner + Widget Extension)

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
    let hourlyWaveHeights: [HourlyWave]
    let hourlyTideHeights: [HourlyTide]
    let upcomingWindows: [UpcomingWindow]
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

    struct HourlyWave: Identifiable {
        let id: Int
        let hour: Int
        let waveHeight: Double?  // ft
    }

    struct HourlyTide: Identifiable {
        let id: Int
        let hour: Int
        let tideHeight: Double?  // ft
    }

    struct UpcomingWindow: Identifiable {
        let id: Int
        let startTime: String
        let endTime: String
        let score: Int       // 0-100
        let label: String
        let waveHeight: Double?  // ft

        var timeRange: String? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            guard let start = formatter.date(from: startTime),
                  let end = formatter.date(from: endTime) else { return nil }
            let display = DateFormatter()
            display.dateFormat = "ha"
            display.amSymbol = "am"
            display.pmSymbol = "pm"
            return "\(display.string(from: start).lowercased())–\(display.string(from: end).lowercased())"
        }

        var dayLabel: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            guard let date = formatter.date(from: startTime) else { return "" }
            let cal = Calendar.current
            if cal.isDateInToday(date) { return "Today" }
            if cal.isDateInTomorrow(date) { return "Tomorrow" }
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "EEE"
            return dayFmt.string(from: date)
        }

        var conditionColor: Color {
            switch label {
            case "Epic":  return Color(hex: "22c55e")
            case "Good":  return Color(hex: "4db8a4")
            case "Fair":  return Color(hex: "f59e0b")
            case "Poor":  return Color(hex: "ef4444")
            default:      return Color(hex: "4db8a4")
            }
        }
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

    var isStale: Bool {
        guard let fetched = fetchedAt else { return true }
        return Date().timeIntervalSince(fetched) > 3600 // >1 hour
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
        hourlyWaveHeights: (0..<18).map { i in
            HourlyWave(id: i, hour: (6 + i) % 24, waveHeight: Double.random(in: 1.5...4.5))
        },
        hourlyTideHeights: (0..<18).map { i in
            HourlyTide(id: i, hour: (6 + i) % 24, tideHeight: sin(Double(i) / 6.0 * .pi) * 2.5 + 2.0)
        },
        upcomingWindows: [
            UpcomingWindow(id: 0, startTime: "2026-03-04T07:00", endTime: "2026-03-04T10:00", score: 78, label: "Good", waveHeight: 3.2),
            UpcomingWindow(id: 1, startTime: "2026-03-05T08:00", endTime: "2026-03-05T11:00", score: 65, label: "Good", waveHeight: 2.8),
            UpcomingWindow(id: 2, startTime: "2026-03-06T06:00", endTime: "2026-03-06T09:00", score: 52, label: "Fair", waveHeight: 2.1),
        ],
        bestWindowStart: "",
        bestWindowEnd: "",
        bestWindowScore: 78,
        bestWindowLabel: "Good"
    )
}

// MARK: - UserDefaults Reader

extension WidgetData {
    static func read() -> WidgetData {
        let defaults = UserDefaults(suiteName: "group.com.boardcast.app")

        let score = defaults?.integer(forKey: "score") ?? 0
        let conditionLabel = defaults?.string(forKey: "conditionLabel") ?? "Poor"
        let locationName = defaults?.string(forKey: "locationName") ?? "No location"
        let waveHeight = defaults?.string(forKey: "waveHeight") ?? "--"
        let windSpeed = defaults?.string(forKey: "windSpeed") ?? "--"
        let windDir = defaults?.string(forKey: "windDir") ?? "--"
        let windContext = defaults?.string(forKey: "windContext") ?? ""
        let fetchedAtStr = defaults?.string(forKey: "fetchedAt") ?? ""
        let hourlyJson = defaults?.string(forKey: "hourlyScores") ?? "[]"
        let waveJson = defaults?.string(forKey: "hourlyWaveHeights") ?? "[]"
        let tideJson = defaults?.string(forKey: "hourlyTideHeights") ?? "[]"
        let windowsJson = defaults?.string(forKey: "upcomingWindows") ?? "[]"
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

        // Parse wave heights
        var hourlyWaveHeights: [HourlyWave] = []
        if let data = waveJson.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            hourlyWaveHeights = arr.enumerated().map { (i, obj) in
                HourlyWave(
                    id: i,
                    hour: obj["h"] as? Int ?? 0,
                    waveHeight: obj["w"] as? Double
                )
            }
        }

        // Parse tide heights
        var hourlyTideHeights: [HourlyTide] = []
        if let data = tideJson.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            hourlyTideHeights = arr.enumerated().map { (i, obj) in
                HourlyTide(
                    id: i,
                    hour: obj["h"] as? Int ?? 0,
                    tideHeight: obj["t"] as? Double
                )
            }
        }

        // Parse upcoming windows
        var upcomingWindows: [UpcomingWindow] = []
        if let data = windowsJson.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            upcomingWindows = arr.enumerated().map { (i, obj) in
                UpcomingWindow(
                    id: i,
                    startTime: obj["start"] as? String ?? "",
                    endTime: obj["end"] as? String ?? "",
                    score: obj["score"] as? Int ?? 0,
                    label: obj["label"] as? String ?? "Poor",
                    waveHeight: obj["wave"] as? Double
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
            hourlyWaveHeights: hourlyWaveHeights,
            hourlyTideHeights: hourlyTideHeights,
            upcomingWindows: upcomingWindows,
            bestWindowStart: bestStart,
            bestWindowEnd: bestEnd,
            bestWindowScore: bestScore,
            bestWindowLabel: bestLabel
        )
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
