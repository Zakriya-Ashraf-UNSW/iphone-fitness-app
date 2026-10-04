import Foundation
import Capacitor
import ActivityKit

@objc(LiveActivityPlugin)
public class LiveActivityPlugin: CAPPlugin, CAPBridgedPlugin {
    public static let sharedInstance = LiveActivityPlugin()

    public let identifier = "LiveActivityPlugin"
    public let jsName = "LiveActivity"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "startActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "endActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isSupported", returnType: CAPPluginReturnPromise)
    ]

    private static var currentActivity: Any? = nil
    private static let activityLock = NSLock()
    private static var isRequestingActivity = false

    @objc func isSupported(_ call: CAPPluginCall) {
        if #available(iOS 16.1, *) {
            let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
            call.resolve(["supported": true, "enabled": enabled])
        } else {
            call.resolve(["supported": false, "enabled": false])
        }
    }

    private func extractContentState(from call: CAPPluginCall) -> WorkoutActivityAttributes.ContentState {
        let split = call.getString("splitName") ?? "PUSH"
        let exerciseName = call.getString("exerciseName") ?? "Smith Incline"
        let setIndex = call.getInt("setIndex") ?? 2
        let totalSets = call.getInt("totalSets") ?? 3
        let loadText = call.getString("loadText") ?? (call.getString("weightText") ?? "115.0 LBS")
        let targetReps = call.getString("targetRepsText") ?? (call.getString("repsText") ?? "8-12 Reps")
        let isResting = call.getBool("isResting") ?? false
        let restDuration = call.getDouble("restDuration") ?? 0
        let isTriageLogging = call.getBool("isTriageLogging") ?? false
        let underTarget = call.getString("underTargetText") ?? "< 8 Missed"
        let prescribed = call.getString("prescribedTargetText") ?? "8-11 Target"
        let overload = call.getString("overloadTargetText") ?? "12+ Overload"
        let increment = call.getString("overloadIncrementText") ?? "+5 lbs Next"
        let isRecap = call.getBool("isRecap") ?? false
        let recapLoggedSets = call.getString("recapLoggedSetsText") ?? ""
        let recapProgressionHeadline = call.getString("recapProgressionHeadline") ?? ""
        let recapNextTarget = call.getString("recapNextTargetText") ?? ""
        let recapIsFinalExercise = call.getBool("recapIsFinalExercise") ?? false

        let isWarmup = call.getBool("isWarmup") ?? false
        let warmupIndex = call.getInt("warmupIndex") ?? 1
        let totalWarmups = call.getInt("totalWarmups") ?? 0
        let warmupTargetText = call.getString("warmupTargetText") ?? ""
        let isTransitionRest = call.getBool("isTransitionRest") ?? false
        let nextExerciseName = call.getString("nextExerciseName") ?? ""

        var restEndTimestamp: TimeInterval? = nil
        if isResting && restDuration > 0 {
            restEndTimestamp = Date().addingTimeInterval(restDuration).timeIntervalSince1970
        }

        return WorkoutActivityAttributes.ContentState(
            splitName: split,
            exerciseName: exerciseName,
            setIndex: setIndex,
            totalSets: totalSets,
            loadText: loadText,
            targetRepsText: targetReps,
            isResting: isResting,
            restEndTimestamp: restEndTimestamp,
            isTriageLogging: isTriageLogging,
            underTargetText: underTarget,
            prescribedTargetText: prescribed,
            overloadTargetText: overload,
            overloadIncrementText: increment,
            isRecap: isRecap,
            recapLoggedSetsText: recapLoggedSets,
            recapProgressionHeadline: recapProgressionHeadline,
            recapNextTargetText: recapNextTarget,
            recapIsFinalExercise: recapIsFinalExercise,
            isWarmup: isWarmup,
            warmupIndex: warmupIndex,
            totalWarmups: totalWarmups,
            warmupTargetText: warmupTargetText,
            isTransitionRest: isTransitionRest,
            nextExerciseName: nextExerciseName
        )
    }

    @objc func startActivity(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Live Activities require iOS 16.1+")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            call.reject("Live Activities are disabled in iOS Settings for Overload")
            return
        }

        let initialState = extractContentState(from: call)

        // If an active activity already exists, reuse and update all active instances to ensure full UI synchronization
        let activeActivities = Activity<WorkoutActivityAttributes>.activities.filter { $0.activityState == .active }
        if let primary = activeActivities.first {
            Self.currentActivity = primary
            Task {
                let content = ActivityContent(state: initialState, staleDate: nil)
                for act in activeActivities {
                    if #available(iOS 16.2, *) {
                        await act.update(content)
                    } else {
                        await act.update(using: initialState)
                    }
                }
                // Dismiss any duplicate activities so only one remains active on Dynamic Island
                if activeActivities.count > 1 {
                    for extra in activeActivities.dropFirst() {
                        await extra.end(dismissalPolicy: .immediate)
                    }
                }
                call.resolve([
                    "activityId": primary.id,
                    "status": "reused_active"
                ])
            }
            return
        }

        // Lock to serialize activity creation and eliminate race condition duplicates
        Self.activityLock.lock()
        if Self.isRequestingActivity {
            Self.activityLock.unlock()
            call.resolve(["status": "already_starting"])
            return
        }
        Self.isRequestingActivity = true
        Self.activityLock.unlock()

        Task {
            // Clean up any dead/orphaned activity instances before requesting a new one
            for dead in Activity<WorkoutActivityAttributes>.activities {
                await dead.end(dismissalPolicy: .immediate)
            }

            do {
                let activity = try Activity<WorkoutActivityAttributes>.request(
                    attributes: WorkoutActivityAttributes(),
                    contentState: initialState,
                    pushType: nil
                )
                Self.currentActivity = activity
                Self.activityLock.lock()
                Self.isRequestingActivity = false
                Self.activityLock.unlock()

                call.resolve([
                    "activityId": activity.id,
                    "status": "started"
                ])
            } catch {
                Self.activityLock.lock()
                Self.isRequestingActivity = false
                Self.activityLock.unlock()
                call.reject("Failed to start Live Activity: \(error.localizedDescription)")
            }
        }
    }

    @objc func updateActivity(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Not supported on this iOS version")
            return
        }

        let activeActivities = Activity<WorkoutActivityAttributes>.activities.filter { $0.activityState == .active }
        guard !activeActivities.isEmpty else {
            // No active Live Activity exists in system; start a fresh one automatically
            startActivity(call)
            return
        }

        Self.currentActivity = activeActivities.first
        let updatedState = extractContentState(from: call)

        Task {
            let content = ActivityContent(state: updatedState, staleDate: nil)
            for activity in activeActivities {
                if #available(iOS 16.2, *) {
                    await activity.update(content)
                } else {
                    await activity.update(using: updatedState)
                }
            }
            // Dismiss duplicate activities if multiple are registered in system
            if activeActivities.count > 1 {
                for extra in activeActivities.dropFirst() {
                    await extra.end(dismissalPolicy: .immediate)
                }
            }
            call.resolve(["status": "updated"])
        }
    }

    @objc func endActivity(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.resolve(["status": "unsupported"])
            return
        }

        Task {
            for act in Activity<WorkoutActivityAttributes>.activities {
                await act.end(dismissalPolicy: .immediate)
            }
            Self.currentActivity = nil
            call.resolve(["status": "ended"])
        }
    }

    // Direct WebKit fallback handler
    public func handleDirectMessage(_ data: [String: Any]) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let action = data["action"] as? String ?? "update"
        if action == "end" {
            Task {
                for act in Activity<WorkoutActivityAttributes>.activities {
                    await act.end(dismissalPolicy: .immediate)
                }
                Self.currentActivity = nil
            }
            return
        }

        let split = data["splitName"] as? String ?? "PUSH"
        let exerciseName = data["exerciseName"] as? String ?? "Smith Incline"
        let setIndex = data["setIndex"] as? Int ?? 2
        let totalSets = data["totalSets"] as? Int ?? 3
        let loadText = data["loadText"] as? String ?? (data["weightText"] as? String ?? "115.0 LBS")
        let targetReps = data["targetRepsText"] as? String ?? (data["repsText"] as? String ?? "8-12 Reps")
        let isResting = data["isResting"] as? Bool ?? false
        let restDuration = data["restDuration"] as? Double ?? 0
        let isTriageLogging = data["isTriageLogging"] as? Bool ?? false
        let underTarget = data["underTargetText"] as? String ?? "< 8 Missed"
        let prescribed = data["prescribedTargetText"] as? String ?? "8-11 Target"
        let overload = data["overloadTargetText"] as? String ?? "12+ Overload"
        let increment = data["overloadIncrementText"] as? String ?? "+5 lbs Next"
        let isRecap = data["isRecap"] as? Bool ?? false
        let recapLoggedSets = data["recapLoggedSetsText"] as? String ?? ""
        let recapProgressionHeadline = data["recapProgressionHeadline"] as? String ?? ""
        let recapNextTarget = data["recapNextTargetText"] as? String ?? ""
        let recapIsFinalExercise = data["recapIsFinalExercise"] as? Bool ?? false

        let isWarmup = data["isWarmup"] as? Bool ?? false
        let warmupIndex = data["warmupIndex"] as? Int ?? 1
        let totalWarmups = data["totalWarmups"] as? Int ?? 0
        let warmupTargetText = data["warmupTargetText"] as? String ?? ""
        let isTransitionRest = data["isTransitionRest"] as? Bool ?? false
        let nextExerciseName = data["nextExerciseName"] as? String ?? ""

        var restEndTimestamp: TimeInterval? = nil
        if isResting && restDuration > 0 {
            restEndTimestamp = Date().addingTimeInterval(restDuration).timeIntervalSince1970
        }

        let contentState = WorkoutActivityAttributes.ContentState(
            splitName: split,
            exerciseName: exerciseName,
            setIndex: setIndex,
            totalSets: totalSets,
            loadText: loadText,
            targetRepsText: targetReps,
            isResting: isResting,
            restEndTimestamp: restEndTimestamp,
            isTriageLogging: isTriageLogging,
            underTargetText: underTarget,
            prescribedTargetText: prescribed,
            overloadTargetText: overload,
            overloadIncrementText: increment,
            isRecap: isRecap,
            recapLoggedSetsText: recapLoggedSets,
            recapProgressionHeadline: recapProgressionHeadline,
            recapNextTargetText: recapNextTarget,
            recapIsFinalExercise: recapIsFinalExercise,
            isWarmup: isWarmup,
            warmupIndex: warmupIndex,
            totalWarmups: totalWarmups,
            warmupTargetText: warmupTargetText,
            isTransitionRest: isTransitionRest,
            nextExerciseName: nextExerciseName
        )

        let activeActivities = Activity<WorkoutActivityAttributes>.activities.filter { $0.activityState == .active }

        Task {
            if !activeActivities.isEmpty {
                Self.currentActivity = activeActivities.first
                let content = ActivityContent(state: contentState, staleDate: nil)
                for activity in activeActivities {
                    if #available(iOS 16.2, *) {
                        await activity.update(content)
                    } else {
                        await activity.update(using: contentState)
                    }
                }
                if activeActivities.count > 1 {
                    for extra in activeActivities.dropFirst() {
                        await extra.end(dismissalPolicy: .immediate)
                    }
                }
            } else {
                Self.activityLock.lock()
                guard !Self.isRequestingActivity else {
                    Self.activityLock.unlock()
                    return
                }
                Self.isRequestingActivity = true
                Self.activityLock.unlock()

                for dead in Activity<WorkoutActivityAttributes>.activities {
                    await dead.end(dismissalPolicy: .immediate)
                }
                do {
                    let activity = try Activity<WorkoutActivityAttributes>.request(
                        attributes: WorkoutActivityAttributes(),
                        contentState: contentState,
                        pushType: nil
                    )
                    Self.currentActivity = activity
                } catch {
                    print("Error starting Live Activity: \(error)")
                }
                Self.activityLock.lock()
                Self.isRequestingActivity = false
                Self.activityLock.unlock()
            }
        }
    }
}
