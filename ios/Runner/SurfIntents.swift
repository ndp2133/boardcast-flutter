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
        guard data.score > 0 || data.conditionLabel != "Poor" || data.locationName != "No location" else {
            return .result(
                dialog: "I don't have any surf data yet. Open Boardcast to fetch the latest conditions.",
                view: ConditionsSnippetView(data: .placeholder, showStaleWarning: false)
            )
        }

        // If user asked about a different location than what's cached
        if let requested = location, requested.name != data.locationName {
            return .result(
                dialog: "I have conditions for \(data.locationName), not \(requested.name). Switch locations in the app, then ask again.",
                view: ConditionsSnippetView(data: data, showStaleWarning: false)
            )
        }

        let stale = data.isStale
        let tone = dialogTone(for: data.conditionLabel, score: data.score)
        let staleNote = stale ? " (Data is over an hour old — open Boardcast to refresh.)" : ""

        let dialog = "\(tone) \(data.locationName): \(data.conditionLabel) conditions. \(data.waveHeight)ft waves, \(data.windSpeed)mph \(data.windContext) wind from the \(data.windDir).\(staleNote)"

        return .result(
            dialog: IntentDialog(stringLiteral: dialog),
            view: ConditionsSnippetView(data: data, showStaleWarning: stale)
        )
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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = WidgetData.read()

        // No data
        guard data.score > 0 || data.conditionLabel != "Poor" || data.locationName != "No location" else {
            return .result(dialog: "I don't have any surf data yet. Open Boardcast to fetch the latest conditions.")
        }

        // Wrong location
        if let requested = location, requested.name != data.locationName {
            return .result(dialog: "I have data for \(data.locationName), not \(requested.name). Switch locations in the app, then ask again.")
        }

        // No best window
        guard let timeRange = data.bestWindowTimeRange else {
            return .result(dialog: "No standout window today at \(data.locationName). Conditions are \(data.conditionLabel.lowercased()) across the board.")
        }

        let staleNote = data.isStale ? " (Data may be stale — open Boardcast to refresh.)" : ""
        let tone: String
        switch data.bestWindowLabel {
        case "Epic":  tone = "🤙 Don't miss it!"
        case "Good":  tone = "Worth getting out there."
        case "Fair":  tone = "Manageable if you're keen."
        default:      tone = ""
        }

        return .result(dialog: IntentDialog(stringLiteral: "Best window at \(data.locationName): \(timeRange) — \(data.bestWindowLabel) conditions (score: \(data.bestWindowScore)). \(tone)\(staleNote)"))
    }
}
