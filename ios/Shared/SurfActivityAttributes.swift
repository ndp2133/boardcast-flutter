import ActivityKit
import Foundation

struct SurfActivityAttributes: ActivityAttributes {
    let locationName: String
    let locationId: String

    struct ContentState: Codable, Hashable {
        let score: Int
        let conditionLabel: String
        let waveHeight: String
        let windSpeed: String
        let windDir: String
        let windContext: String
        let bestWindowRange: String  // pre-formatted "7am–10am"
        let bestWindowLabel: String
        let updatedAt: Date
    }
}
