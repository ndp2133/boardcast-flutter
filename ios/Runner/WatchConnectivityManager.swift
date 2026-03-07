import Foundation
import Flutter

#if canImport(WatchConnectivity)
import WatchConnectivity

/// Bridges Flutter -> WatchConnectivity to push surf data to Apple Watch complications.
/// Called via MethodChannel "com.boardcast.app/watch".
class WatchConnectivityManager: NSObject, WCSessionDelegate, FlutterPlugin {
    private var session: WCSession?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.boardcast.app/watch", binaryMessenger: registrar.messenger())
        let instance = WatchConnectivityManager()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Flutter Method Channel

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateWatchData":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected dictionary", details: nil))
                return
            }
            sendToWatch(args, result: result)
        case "isWatchReachable":
            result(session?.isReachable ?? false)
        case "isWatchPaired":
            result(session?.isPaired ?? false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func sendToWatch(_ data: [String: Any], result: @escaping FlutterResult) {
        guard let session = session, session.activationState == .activated else {
            result(FlutterError(code: "NOT_ACTIVATED", message: "WCSession not activated", details: nil))
            return
        }

        if session.isPaired && session.isWatchAppInstalled {
            if session.remainingComplicationUserInfoTransfers > 0 {
                session.transferCurrentComplicationUserInfo(data)
            } else {
                try? session.updateApplicationContext(data)
            }
            result(true)
        } else {
            try? session.updateApplicationContext(data)
            result(false)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("[WatchConnectivity] Activation error: \(error.localizedDescription)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

#else

/// Stub when WatchConnectivity is not available (e.g. simulator without watch pairing)
class WatchConnectivityManager: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.boardcast.app/watch", binaryMessenger: registrar.messenger())
        let instance = WatchConnectivityManager()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isWatchReachable", "isWatchPaired":
            result(false)
        case "updateWatchData":
            result(false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

#endif
