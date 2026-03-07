import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct BoardcastWatchApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

// MARK: - Hourly Forecast Entry

struct HourlyEntry: Identifiable {
    let id: Int
    let hour: Int
    let score: Int
    let wave: String
    let windSpeed: String
    let windDir: String

    var hourLabel: String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    var conditionColor: Color {
        if score >= 80 { return Color(red: 34/255, green: 197/255, blue: 94/255) }
        if score >= 60 { return Color(red: 77/255, green: 184/255, blue: 164/255) }
        if score >= 40 { return Color(red: 245/255, green: 158/255, blue: 11/255) }
        return Color(red: 239/255, green: 68/255, blue: 68/255)
    }
}

// MARK: - Watch App View

struct WatchContentView: View {
    @AppStorage("watch_score") private var score: Int = 0
    @AppStorage("watch_conditionLabel") private var conditionLabel: String = "\u{2014}"
    @AppStorage("watch_locationName") private var locationName: String = "Open Boardcast on iPhone"
    @AppStorage("watch_waveHeight") private var waveHeight: String = "--"
    @AppStorage("watch_windSpeed") private var windSpeed: String = "--"
    @AppStorage("watch_windDir") private var windDir: String = "--"
    @AppStorage("watch_bestWindowRange") private var bestWindowRange: String = ""
    @AppStorage("watch_bestWindowLabel") private var bestWindowLabel: String = ""
    @AppStorage("watch_hourlyForecast") private var hourlyForecastJSON: String = "[]"

    private let teal = Color(red: 77/255, green: 184/255, blue: 164/255)

    var conditionColor: Color {
        switch conditionLabel {
        case "Epic":  return Color(red: 34/255, green: 197/255, blue: 94/255)
        case "Good":  return teal
        case "Fair":  return Color(red: 245/255, green: 158/255, blue: 11/255)
        case "Poor":  return Color(red: 239/255, green: 68/255, blue: 68/255)
        default:      return teal
        }
    }

    var hourlyEntries: [HourlyEntry] {
        guard let data = hourlyForecastJSON.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.enumerated().compactMap { (i, dict) in
            guard let h = dict["h"] as? Int,
                  let s = dict["s"] as? Int else { return nil }
            return HourlyEntry(
                id: i,
                hour: h,
                score: s,
                wave: dict["w"] as? String ?? "--",
                windSpeed: dict["ws"] as? String ?? "--",
                windDir: dict["wd"] as? String ?? "--"
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(conditionColor.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(conditionColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(width: 80, height: 80)

                Text(conditionLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(conditionColor)

                Text(locationName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(waveHeight)ft", systemImage: "water.waves")
                        .font(.system(size: 11))
                    Label("\(windSpeed)mph \(windDir)", systemImage: "wind")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)

                // Best window
                if !bestWindowRange.isEmpty {
                    Divider().padding(.vertical, 2)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                        Text("Best: \(bestWindowRange)")
                            .font(.system(size: 12, weight: .medium))
                        Text(bestWindowLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(conditionColor)
                    }
                }

                // Hourly forecast
                let entries = hourlyEntries
                if !entries.isEmpty {
                    Divider().padding(.vertical, 2)
                    Text("Next Hours")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(entries) { entry in
                        HStack(spacing: 0) {
                            Text(entry.hourLabel)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 30, alignment: .leading)

                            // Mini score bar
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(entry.conditionColor)
                                    .frame(width: geo.size.width * CGFloat(entry.score) / 100.0)
                            }
                            .frame(height: 8)
                            .frame(maxWidth: .infinity)

                            Text("\(entry.score)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .frame(width: 28, alignment: .trailing)

                            Text("\(entry.wave)ft")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .frame(height: 16)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - WatchConnectivity Delegate

class WatchAppDelegate: NSObject, WKApplicationDelegate, WCSessionDelegate {
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation error: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async {
            Self.storeAndReload(userInfo)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            Self.storeAndReload(applicationContext)
        }
    }

    static func storeAndReload(_ data: [String: Any]) {
        let defaults = UserDefaults.standard
        for (key, value) in data {
            defaults.set(value, forKey: "watch_\(key)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
