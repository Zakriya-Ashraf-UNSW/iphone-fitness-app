import Foundation
import ActivityKit

@available(iOS 16.1, *)
public final class LiveActivityManager: @unchecked Sendable {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>? = nil
    private let lock = NSLock()

    private init() {}

    public func isSupported() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    public func syncWorkoutState(_ state: WorkoutActivityAttributes.ContentState) {
        guard isSupported() else { return }

        lock.lock()
        defer { lock.unlock() }

        let activeActivities = Activity<WorkoutActivityAttributes>.activities.filter { $0.activityState == .active }
        if let existing = activeActivities.first {
            currentActivity = existing
            Task {
                if #available(iOS 16.2, *) {
                    await existing.update(ActivityContent(state: state, staleDate: nil))
                } else {
                    await existing.update(using: state)
                }
            }
            // Dismiss duplicate activities
            if activeActivities.count > 1 {
                for duplicate in activeActivities.dropFirst() {
                    Task { await duplicate.end(dismissalPolicy: .immediate) }
                }
            }
            return
        }

        // Request new activity
        let attributes = WorkoutActivityAttributes()
        do {
            let activity: Activity<WorkoutActivityAttributes>
            if #available(iOS 16.2, *) {
                activity = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil)
            } else {
                activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
            self.currentActivity = activity
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    public func endActivity() {
        lock.lock()
        defer { lock.unlock() }

        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}
