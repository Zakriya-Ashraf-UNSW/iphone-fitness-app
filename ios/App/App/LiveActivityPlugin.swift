import Foundation
import Capacitor
import ActivityKit

@objc(LiveActivityPlugin)
public class LiveActivityPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "LiveActivityPlugin"
    public let jsName = "LiveActivity"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "startActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "endActivity", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isSupported", returnType: CAPPluginReturnPromise)
    ]

    private var currentActivity: Any? = nil

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
            call.reject("Live Activities are disabled in iOS Settings for this app")
            return
        }

        let attributes = WorkoutActivityAttributes()
        let initialState = extractContentState(from: call)

        do {
            if let existing = currentActivity as? Activity<WorkoutActivityAttributes> {
                Task {
                    await existing.end(dismissalPolicy: .immediate)
                }
            }

            let activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            self.currentActivity = activity
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

        guard let activity = currentActivity as? Activity<WorkoutActivityAttributes> else {
            startActivity(call)
            return
        }

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

        if let activity = currentActivity as? Activity<WorkoutActivityAttributes> {
            Task {
                await activity.end(dismissalPolicy: .immediate)
                self.currentActivity = nil
                call.resolve(["status": "ended"])
            }
        } else {
            call.resolve(["status": "no_active_activity"])
        }
    }
}
