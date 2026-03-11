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
        if score >= 80 { return Color(red: 0x2e/255, green: 0x8a/255, blue: 0x5e/255) }
        if score >= 60 { return Color(red: 0x3d/255, green: 0x91/255, blue: 0x89/255) }
        if score >= 40 { return Color(red: 0xb0/255, green: 0x7a/255, blue: 0x4f/255) }
        return Color(red: 0x9e/255, green: 0x5e/255, blue: 0x5e/255)
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
    @AppStorage("watch_verdict") private var verdict: String = ""
    @AppStorage("watch_trend") private var trend: String = "→"
    @AppStorage("watch_hourlyForecast") private var hourlyForecastJSON: String = "[]"

    // Cold ocean palette — WCAG compliant
    private let teal = Color(red: 0x3d/255, green: 0x91/255, blue: 0x89/255)

    var conditionColor: Color {
        switch conditionLabel {
        case "Epic":  return Color(red: 0x2e/255, green: 0x8a/255, blue: 0x5e/255)
        case "Good":  return teal
        case "Fair":  return Color(red: 0xb0/255, green: 0x7a/255, blue: 0x4f/255)
        case "Poor":  return Color(red: 0x9e/255, green: 0x5e/255, blue: 0x5e/255)
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
            VStack(spacing: 6) {
                // W-1: Verdict-first — the decision leads, not the number
                if !verdict.isEmpty {
                    Text(verdict)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 2)
                }

                // Score ring + condition (secondary)
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(conditionColor.opacity(0.2), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100.0)
                            .stroke(conditionColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(score)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Text(conditionLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(conditionColor)
                            Text(trend)
                                .font(.system(size: 13))
                                .foregroundColor(conditionColor.opacity(0.8))
                        }
                        Text(locationName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Current conditions — compact
                HStack(spacing: 10) {
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
                            .foregroundColor(teal)
                        Text(bestWindowRange)
                            .font(.system(size: 12, weight: .medium))
                        Text(bestWindowLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(conditionColor)
                    }
                }

                // Hourly sparkline
                let entries = hourlyEntries
                if !entries.isEmpty {
                    Divider().padding(.vertical, 2)
                    HourlySparkline(entries: entries)
                        .frame(height: 44)
                }
            }
            .padding()
        }
        .background(
            RadialGradient(
                colors: [conditionColor.opacity(0.10), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 200
            )
        )
    }
}

// MARK: - Hourly Sparkline Chart

struct HourlySparkline: View {
    let entries: [HourlyEntry]
    private let teal = Color(red: 0x3d/255, green: 0x91/255, blue: 0x89/255)

    var body: some View {
        if entries.count > 1 {
            sparklineChart
        }
    }

    private var sparklineChart: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height - 12
            let count = entries.count
            let step = w / CGFloat(count - 1)

            ZStack(alignment: .top) {
                areaFill(h: h, step: step)
                scoreLine(h: h, step: step)
                timeLabels(step: step, fullHeight: geo.size.height)
            }
        }
    }

    private func areaFill(h: CGFloat, step: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: h))
            for i in 0..<entries.count {
                let x = CGFloat(i) * step
                let y = h * (1 - CGFloat(entries[i].score) / 100.0)
                if i == 0 {
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    let px = CGFloat(i - 1) * step
                    let py = h * (1 - CGFloat(entries[i - 1].score) / 100.0)
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: px + step * 0.4, y: py),
                        control2: CGPoint(x: x - step * 0.4, y: y)
                    )
                }
            }
            path.addLine(to: CGPoint(x: CGFloat(entries.count - 1) * step, y: h))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [teal.opacity(0.4), teal.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func scoreLine(h: CGFloat, step: CGFloat) -> some View {
        Path { path in
            for i in 0..<entries.count {
                let x = CGFloat(i) * step
                let y = h * (1 - CGFloat(entries[i].score) / 100.0)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    let px = CGFloat(i - 1) * step
                    let py = h * (1 - CGFloat(entries[i - 1].score) / 100.0)
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: px + step * 0.4, y: py),
                        control2: CGPoint(x: x - step * 0.4, y: y)
                    )
                }
            }
        }
        .stroke(teal, lineWidth: 1.5)
    }

    private func timeLabels(step: CGFloat, fullHeight: CGFloat) -> some View {
        let labelStep = max(1, entries.count / 4)
        return ZStack {
            ForEach(Array(stride(from: 0, to: entries.count, by: labelStep)), id: \.self) { i in
                Text(entries[i].hourLabel)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .position(x: CGFloat(i) * step, y: fullHeight - 3)
            }
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
