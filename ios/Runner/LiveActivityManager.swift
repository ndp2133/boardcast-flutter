import ActivityKit
import Foundation

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<SurfActivityAttributes>?

    private init() {}

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(locationName: String, locationId: String, state: SurfActivityAttributes.ContentState) {
        // End any existing activity first
        end()

        let attributes = SurfActivityAttributes(
            locationName: locationName,
            locationId: locationId
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(20 * 60) // 20 minutes
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil  // No APNS push in V1
            )
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    func update(state: SurfActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(20 * 60)
        )

        Task {
            await activity.update(content)
        }
    }

    func end() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
