import UIKit
import SwiftUI
import ActivityKit
import SharedWorkoutModels
import os

private let logger = Logger(subsystem: "com.overload.fitnessapp", category: "URLHandler")
private let appGroupID = "group.com.overload.fitnessapp"

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let hostingController = UIHostingController(rootView: MainTabView())
        hostingController.view.backgroundColor = .black

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = hostingController
        window?.makeKeyAndVisible()

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
            dispatchActionToManager(action: action, params: params)
        }
    }

    // MARK: - Handle overload:// URL actions from Dynamic Island buttons
    private func handleOverloadURL(_ url: URL) {
        guard url.scheme == "overload" else { return }
        let action = url.host ?? ""
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        
        logger.info("Handling overload URL: \(url.absoluteString)")
        dispatchActionToManager(action: action, params: params)
    }

    private func dispatchActionToManager(action: String, params: [URLQueryItem]?) {
        DispatchQueue.main.async {
            let manager = WorkoutSessionManager.shared
            switch action {
            case "skip-rest":
                manager.stopRestTimer()
            case "adjust-timer":
                let delta = Int(params?.first(where: { $0.name == "delta" })?.value ?? "0") ?? 0
                manager.adjustRest(by: delta)
            case "log-triage":
                let outcome = params?.first(where: { $0.name == "outcome" })?.value ?? "target"
                if manager.activeSetIndex == 1 {
                    manager.logSet1(outcome: outcome)
                } else if manager.activeSetIndex == 2 {
                    manager.logSet2(outcome: outcome)
                } else {
                    manager.logSet3(outcome: outcome)
                }
            case "log-warmup":
                manager.completeWarmupSet()
            case "skip-warmup":
                manager.skipWarmups()
            case "continue-next-exercise":
                manager.advanceToNextExerciseAfterRecap()
            default:
                logger.warning("Unhandled action: \(action)")
            }
        }
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(center, observer)
    }
}
