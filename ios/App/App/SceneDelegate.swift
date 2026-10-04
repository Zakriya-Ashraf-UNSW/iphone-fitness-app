import UIKit
import Capacitor
import ActivityKit
import SharedWorkoutModels
import os

private let logger = Logger(subsystem: "com.overload.fitnessapp", category: "URLHandler")

private let appGroupID = "group.com.overload.fitnessapp"

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)

        // Handle URL if app was launched via URL
        if let urlContext = connectionOptions.urlContexts.first {
            handleOverloadURL(urlContext.url)
        }

        // Listen for Darwin notifications from the widget extension
        registerForWidgetActions()

        // Also check for any pending widget actions when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkPendingWidgetActions),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle our custom overload:// URLs for Live Activity button actions
        if let urlContext = URLContexts.first(where: { $0.url.scheme == "overload" }) {
            handleOverloadURL(urlContext.url)
        }
        SceneDelegateProxy.shared.scene(scene, openURLContexts: URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        SceneDelegateProxy.shared.scene(scene, continue: userActivity)
    }

    // MARK: - Widget Action IPC via App Group + Darwin Notifications

    private func registerForWidgetActions() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { (_, observer, _, _, _) in
                guard let observer = observer else { return }
                let delegate = Unmanaged<SceneDelegate>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    delegate.checkPendingWidgetActions()
                }
            },
            "com.overload.fitnessapp.widgetAction" as CFString,
            nil,
            .deliverImmediately
        )
        logger.info("Registered for Darwin widget action notifications")
    }

    @objc private func checkPendingWidgetActions() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        var actionsToProcess: [[String: String]] = []
        if let queue = defaults.array(forKey: "pendingWidgetActionsQueue") as? [[String: String]], !queue.isEmpty {
            actionsToProcess = queue
            defaults.removeObject(forKey: "pendingWidgetActionsQueue")
        } else if let single = defaults.dictionary(forKey: "pendingWidgetAction") as? [String: String] {
            actionsToProcess = [single]
        }
        defaults.removeObject(forKey: "pendingWidgetAction")
        defaults.synchronize()

        guard !actionsToProcess.isEmpty else { return }

        for payload in actionsToProcess {
            guard let action = payload["action"] else { continue }
            logger.info("Processing queued widget action: \(action)")

            var params: [URLQueryItem] = []
            for (key, value) in payload where key != "action" && key != "timestamp" {
                params.append(URLQueryItem(name: key, value: value))
            }
            notifyWebviewOfAction(action: action, params: params)
        }
    }

    // MARK: - Handle overload:// URL actions from Dynamic Island buttons
    private func handleOverloadURL(_ url: URL) {
        guard url.scheme == "overload" else { return }
        let action = url.host ?? ""
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        
        logger.info("Handling overload URL: \(url.absoluteString)")

        // Notify Webview so JavaScript engine can process the action in app UI
        notifyWebviewOfAction(action: action, params: params)

        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                var state = activity.content.state
                logger.info("Found activity \(activity.id), processing action: \(action)")

                switch action {
                case "skip-rest":
                    state.isResting = false
                    state.restEndTimestamp = nil
                    state.isTriageLogging = true

                case "adjust-timer":
                    let delta = Int(params?.first(where: { $0.name == "delta" })?.value ?? "0") ?? 0
                    let now = Date().timeIntervalSince1970
                    let currentEnd = state.restEndTimestamp ?? (now + 60)
                    let newEnd = max(now + 1, currentEnd + Double(delta))
                    state.restEndTimestamp = newEnd
                    state.isResting = true
                    logger.info("Adjusted timer by \(delta)s, new end: \(newEnd)")

                case "log-triage":
                    let outcome = params?.first(where: { $0.name == "outcome" })?.value ?? "target"
                    state.isTriageLogging = false
                    if state.setIndex < state.totalSets {
                        state.isResting = true
                        state.restEndTimestamp = Date().addingTimeInterval(90).timeIntervalSince1970
                        state.setIndex += 1
                    } else {
                        // Final set completed - awaiting webview progression recap sync
                        state.isResting = false
                        state.restEndTimestamp = nil
                    }
                    logger.info("Logged triage outcome: \(outcome)")

                case "continue-next-exercise":
                    logger.info("Continue next exercise forwarded to webview")
                    return

                case "log-warmup":
                    logger.info("Log warmup forwarded to webview")
                    return

                case "skip-warmup":
                    logger.info("Skip warmup forwarded to webview")
                    return

                case "enter-exact":
                    logger.info("Enter exact reps/weight - forwarded to webview")
                    return

                default:
                    logger.warning("Unknown action: \(action)")
                    return
                }

                let content = ActivityContent(state: state, staleDate: nil)
                await activity.update(content)
                logger.info("Activity \(activity.id) updated successfully")
            }
        }
    }

    private func notifyWebviewOfAction(action: String, params: [URLQueryItem]?) {
        DispatchQueue.main.async { [weak self] in
            guard let vc = self?.window?.rootViewController as? CAPBridgeViewController ?? (self?.window?.rootViewController as? ViewController) else {
                return
            }
            var paramDict: [String: String] = [:]
            params?.forEach { paramDict[$0.name] = $0.value }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: paramDict),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let js = "if (typeof window.handleLiveActivityAction === 'function') { window.handleLiveActivityAction('\(action)', \(jsonString)); } else { window.__pendingLiveActivityActions = window.__pendingLiveActivityActions || []; window.__pendingLiveActivityActions.push({ action: '\(action)', params: \(jsonString) }); }"
                vc.bridge?.webView?.evaluateJavaScript(js) { (_, error) in
                    if let error = error {
                        logger.error("JavaScript evaluation error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(center, observer)
    }
}
