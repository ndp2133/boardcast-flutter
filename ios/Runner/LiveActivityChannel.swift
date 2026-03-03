import Flutter
import ActivityKit

class LiveActivityChannel {
    static let channelName = "com.boardcast.app/live_activity"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "isSupported":
                if #available(iOS 16.1, *) {
                    result(LiveActivityManager.shared.isSupported)
                } else {
                    result(false)
                }

            case "start":
                guard #available(iOS 16.1, *) else {
                    result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.1+ required", details: nil))
                    return
                }
                guard let args = call.arguments as? [String: Any],
                      let locationName = args["locationName"] as? String,
                      let locationId = args["locationId"] as? String,
                      let state = parseContentState(from: args) else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                    return
                }
                LiveActivityManager.shared.start(
                    locationName: locationName,
                    locationId: locationId,
                    state: state
                )
                result(true)

            case "update":
                guard #available(iOS 16.1, *) else {
                    result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.1+ required", details: nil))
                    return
                }
                guard let args = call.arguments as? [String: Any],
                      let state = parseContentState(from: args) else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                    return
                }
                LiveActivityManager.shared.update(state: state)
                result(true)

            case "end":
                if #available(iOS 16.1, *) {
                    LiveActivityManager.shared.end()
                }
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func parseContentState(from args: [String: Any]) -> SurfActivityAttributes.ContentState? {
        guard let score = args["score"] as? Int,
              let conditionLabel = args["conditionLabel"] as? String,
              let waveHeight = args["waveHeight"] as? String,
              let windSpeed = args["windSpeed"] as? String,
              let windDir = args["windDir"] as? String else {
            return nil
        }

        return SurfActivityAttributes.ContentState(
            score: score,
            conditionLabel: conditionLabel,
            waveHeight: waveHeight,
            windSpeed: windSpeed,
            windDir: windDir,
            windContext: args["windContext"] as? String ?? "",
            bestWindowRange: args["bestWindowRange"] as? String ?? "",
            bestWindowLabel: args["bestWindowLabel"] as? String ?? "",
            updatedAt: Date()
        )
    }
}
