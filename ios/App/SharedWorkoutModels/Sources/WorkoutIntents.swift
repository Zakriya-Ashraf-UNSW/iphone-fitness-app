import ActivityKit
import AppIntents
import Foundation
import os

private let logger = Logger(subsystem: "com.overload.fitnessapp", category: "Intents")
private let appGroupID = "group.com.overload.fitnessapp"

/// Writes an action to the shared App Group UserDefaults and posts a Darwin
/// notification so the main app reacts immediately.
public func notifyAppOfAction(_ action: String, params: [String: String] = [:]) {
    guard let defaults = UserDefaults(suiteName: appGroupID) else {
        logger.error("Failed to access App Group UserDefaults")
        return
    }
    var payload = params
    payload["action"] = action
    payload["timestamp"] = String(Date().timeIntervalSince1970)

    var queue = defaults.array(forKey: "pendingWidgetActionsQueue") as? [[String: String]] ?? []
    queue.append(payload)
    defaults.set(queue, forKey: "pendingWidgetActionsQueue")
    defaults.set(payload, forKey: "pendingWidgetAction")
    defaults.synchronize()
    logger.info("Wrote pendingWidgetAction: \(action) (queue length: \(queue.count))")

    let notificationName = CFNotificationName("com.overload.fitnessapp.widgetAction" as CFString)
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        notificationName,
        nil, nil, true
    )
}

// MARK: - App Intents for Dynamic Island Interactive Buttons

@available(iOS 16.2, *)
public struct SkipRestIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Skip Rest"
    public static var description: IntentDescription = "Immediately completes rest countdown and advances to lifting"
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        logger.info("SkipRestIntent triggered")
        guard #available(iOS 16.2, *) else { return .result() }

        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isResting = false
            state.restEndTimestamp = nil
            state.isTriageLogging = false

            // Update to upcoming set load if available
            if !state.nextSetLoadText.isEmpty {
                state.loadText = state.nextSetLoadText
            }

            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
            logger.info("SkipRestIntent updated Live Activity to active lifting state")
        }

        notifyAppOfAction("skip-rest")
        return .result()
    }
}

@available(iOS 16.2, *)
public struct AdjustTimerIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Adjust Rest Timer"
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Delta Seconds")
    public var deltaSeconds: Int

    public init() {
        self.deltaSeconds = 30
    }

    public init(delta: Int) {
        self.deltaSeconds = delta
    }

    public func perform() async throws -> some IntentResult {
        logger.info("AdjustTimerIntent called with adjustment: \(deltaSeconds)")
        guard #available(iOS 16.2, *) else { return .result() }

        let activities = Activity<WorkoutActivityAttributes>.activities
        let now = Date().timeIntervalSince1970
        for activity in activities {
            var state = activity.content.state
            let currentEnd = state.restEndTimestamp ?? (now + 60)
            let newEnd = max(now + 1, currentEnd + Double(deltaSeconds))
            state.restEndTimestamp = newEnd
            state.isResting = true

            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
            logger.info("AdjustTimerIntent updated Live Activity, newEnd: \(newEnd)")
        }

        notifyAppOfAction("adjust-timer", params: ["delta": String(deltaSeconds)])
        return .result()
    }
}

@available(iOS 16.2, *)
public struct LogTriageIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Log Set Outcome"
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Outcome")
    public var outcome: String // "missed", "target", "overload"

    public init() {
        self.outcome = "target"
    }

    public init(outcome: String) {
        self.outcome = outcome
    }

    public func perform() async throws -> some IntentResult {
        logger.info("LogTriageIntent triggered with outcome: \(outcome)")
        guard #available(iOS 16.2, *) else { return .result() }

        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isTriageLogging = false

            if state.setIndex < state.totalSets {
                state.setIndex += 1
                state.isResting = true
                state.restEndTimestamp = Date().addingTimeInterval(120).timeIntervalSince1970
                state.restTimerLabel = "REST FOR SET \(state.setIndex)"
                if !state.nextSetLoadText.isEmpty {
                    state.loadText = state.nextSetLoadText
                }
            } else {
                state.isRecap = true
                state.isResting = false
                state.restEndTimestamp = nil
                state.recapProgressionHeadline = outcome == "overload" ? "HYPERTROPHY OVERLOAD CLEARED" : (outcome == "target" ? "PRESCRIBED TARGET WINDOW MET" : "WORKING LOAD CONSOLIDATED")
            }

            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
            logger.info("LogTriageIntent updated Live Activity state successfully")
        }

        notifyAppOfAction("log-triage", params: ["outcome": outcome])
        return .result()
    }
}

@available(iOS 16.2, *)
public struct OpenTriageIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Show Outcome Options"
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        logger.info("OpenTriageIntent triggered")
        guard #available(iOS 16.2, *) else { return .result() }

        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isTriageLogging = true
            state.isResting = false
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
        notifyAppOfAction("open-triage")
        return .result()
    }
}

@available(iOS 16.2, *)
public struct ContinueNextExerciseIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Continue to Next Lift"
    public static var description: IntentDescription = "Advances to the next exercise after viewing progression recap"
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        logger.info("ContinueNextExerciseIntent triggered")
        guard #available(iOS 16.2, *) else { return .result() }

        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isRecap = false
            state.isTransitionRest = true
            state.setIndex = 1
            state.isResting = true
            state.restEndTimestamp = Date().addingTimeInterval(90).timeIntervalSince1970
            state.restTimerLabel = "TRANSITION REST"
            state.isTriageLogging = false
            if !state.nextExerciseName.isEmpty {
                state.exerciseName = state.nextExerciseName
                state.nextExerciseName = ""
            }
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }

        notifyAppOfAction("continue-next-exercise")
        return .result()
    }
}

@available(iOS 16.2, *)
public struct LogWarmupIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Complete Warm-Up"
    public static var description: IntentDescription = "Logs the current warm-up set and starts prescribed rest"
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        logger.info("LogWarmupIntent triggered")
        guard #available(iOS 16.2, *) else { return .result() }

        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isResting = true
            state.restEndTimestamp = Date().addingTimeInterval(60).timeIntervalSince1970
            state.restTimerLabel = "REST FOR WARM-UP \(state.warmupIndex + 1)"
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }

        notifyAppOfAction("log-warmup")
        return .result()
    }
}

@available(iOS 16.2, *)
public struct SkipWarmupsIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Skip Warm-Ups"
    public static var description: IntentDescription = "Skips warm-ups and begins Anchor Set 1"
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        logger.info("SkipWarmupsIntent triggered")
        guard #available(iOS 16.2, *) else { return .result() }

        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isWarmup = false
            state.setIndex = 1
            state.isResting = false
            state.restEndTimestamp = nil
            state.isTriageLogging = false
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }

        notifyAppOfAction("skip-warmup")
        return .result()
    }
}
