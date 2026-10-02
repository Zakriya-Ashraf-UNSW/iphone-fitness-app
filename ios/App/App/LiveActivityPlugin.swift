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
            overloadIncrementText: increment
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

        let attributes = WorkoutActivityAttributes()
        let initialState = extractContentState(from: call)

        do {
            // End any previous/orphaned activities to prevent duplicates
            for existing in Activity<WorkoutActivityAttributes>.activities {
                Task {
                    await existing.end(dismissalPolicy: .immediate)
                }
            }

            let activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            Self.currentActivity = activity
            call.resolve([
                "activityId": activity.id,
                "status": "started"
            ])
        } catch {
            call.reject("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    @objc func updateActivity(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Not supported on this iOS version")
            return
        }

        // Use in-memory reference or adopt the active system Live Activity if app reloaded
        let targetActivity = (Self.currentActivity as? Activity<WorkoutActivityAttributes>) ?? Activity<WorkoutActivityAttributes>.activities.first

        guard let activity = targetActivity else {
            startActivity(call)
            return
        }
        Self.currentActivity = activity

        let updatedState = extractContentState(from: call)

        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: updatedState, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: updatedState)
            }
            call.resolve(["status": "updated"])
        }
    }

    @objc func endActivity(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.resolve(["status": "unsupported"])
            return
        }

        if let activity = Self.currentActivity as? Activity<WorkoutActivityAttributes> {
            Task {
                await activity.end(dismissalPolicy: .immediate)
                Self.currentActivity = nil
                call.resolve(["status": "ended"])
            }
        } else {
            call.resolve(["status": "no_active_activity"])
        }
    }

    // Direct WebKit fallback handler
    public func handleDirectMessage(_ data: [String: Any]) {
        guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let action = data["action"] as? String ?? "update"
        if action == "end" {
            if let activity = Self.currentActivity as? Activity<WorkoutActivityAttributes> {
                Task {
                    await activity.end(dismissalPolicy: .immediate)
                    Self.currentActivity = nil
                }
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
            overloadIncrementText: increment
        )

        Task {
            if let activity = Self.currentActivity as? Activity<WorkoutActivityAttributes> {
                if #available(iOS 16.2, *) {
                    await activity.update(ActivityContent(state: contentState, staleDate: nil))
                } else {
                    await activity.update(using: contentState)
                }
            } else {
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
            }
        }
    }
}
