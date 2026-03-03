import AppIntents
import SwiftUI

// MARK: - Check Conditions Intent

struct CheckConditionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Surf Conditions"
    static var description = IntentDescription("Check current surf conditions at your spot")
    static var openAppWhenRun = false

    @Parameter(title: "Location")
    var location: LocationEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let data = WidgetData.read()

        // No data available
        guard data.locationName != "No location", data.fetchedAt != nil else {
            return .result(
                dialog: "I don't have any surf data yet. Open Boardcast to fetch the latest conditions.",
                view: ConditionsSnippetView(data: .placeholder, showStaleWarning: false)
            )
        }

        // If user asked about a different location than what's cached
        if let requested = location, requested.name != data.locationName {
            return .result(
                dialog: IntentDialog(stringLiteral: "I have conditions for \(data.locationName). To check \(requested.name), tap the location name in Boardcast to switch, then ask me again."),
                view: ConditionsSnippetView(data: data, showStaleWarning: false)
            )
        }

        let stale = data.isStale
        let greeting = timeOfDayGreeting()
        let tone = dialogTone(for: data.conditionLabel, score: data.score)
        let staleNote = stale ? " (Data is over an hour old — open Boardcast to refresh.)" : ""

        let dialog = "\(greeting) \(tone) \(data.locationName): \(data.conditionLabel) conditions. \(data.waveHeight)ft waves, \(data.windSpeed)mph \(data.windContext) wind from the \(data.windDir).\(staleNote)"

        return .result(
            dialog: IntentDialog(stringLiteral: dialog),
            view: ConditionsSnippetView(data: data, showStaleWarning: stale)
        )
    }

    private func timeOfDayGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning!"
        case 12..<17: return "Afternoon check —"
        case 17..<21: return "Evening check —"
        default:      return "Late night check —"
        }
    }

    private func dialogTone(for label: String, score: Int) -> String {
        switch label {
        case "Epic":  return "🤙 It's firing!"
        case "Good":  return "Looking solid."
        case "Fair":  return "Decent out there."
        case "Poor":  return "Hmm, not great."
        default:      return ""
        }
    }
}

// MARK: - Get Best Time Intent

struct GetBestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Best Time to Surf"
    static var description = IntentDescription("Find the best window to surf today")
    static var openAppWhenRun = false

    @Parameter(title: "Location")
    var location: LocationEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let data = WidgetData.read()

        // No data
        guard data.locationName != "No location", data.fetchedAt != nil else {
            return .result(
                dialog: "I don't have any surf data yet. Open Boardcast to fetch the latest conditions.",
                view: BestTimeSnippetView(data: .placeholder, timeRange: nil, showStaleWarning: false)
            )
        }

        // Wrong location
        if let requested = location, requested.name != data.locationName {
            return .result(
                dialog: IntentDialog(stringLiteral: "I have data for \(data.locationName). To check \(requested.name), tap the location name in Boardcast to switch, then ask me again."),
                view: BestTimeSnippetView(data: data, timeRange: nil, showStaleWarning: false)
            )
        }

        let stale = data.isStale
        let timeRange = data.bestWindowTimeRange

        // No best window
        guard let range = timeRange else {
            return .result(
                dialog: IntentDialog(stringLiteral: "No standout window today at \(data.locationName). Conditions are \(data.conditionLabel.lowercased()) across the board."),
                view: BestTimeSnippetView(data: data, timeRange: nil, showStaleWarning: stale)
            )
        }

        // Date context — is the best window today or tomorrow?
        let dateContext = bestWindowDateContext(data: data)

        let staleNote = stale ? " (Data may be stale — open Boardcast to refresh.)" : ""
        let tone: String
        switch data.bestWindowLabel {
        case "Epic":  tone = "🤙 Don't miss it!"
        case "Good":  tone = "Worth getting out there."
        case "Fair":  tone = "Manageable if you're keen."
        default:      tone = ""
        }

        return .result(
            dialog: IntentDialog(stringLiteral: "Best window\(dateContext) at \(data.locationName): \(range) — \(data.bestWindowLabel) conditions (score: \(data.bestWindowScore)). \(tone)\(staleNote)"),
            view: BestTimeSnippetView(data: data, timeRange: range, showStaleWarning: stale)
        )
    }

    private func bestWindowDateContext(data: WidgetData) -> String {
        guard !data.bestWindowStart.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let windowDate = formatter.date(from: data.bestWindowStart) else { return "" }

        let cal = Calendar.current
        if cal.isDateInToday(windowDate) {
            return " today"
        } else if cal.isDateInTomorrow(windowDate) {
            return " tomorrow"
        }
        return ""
    }
}
