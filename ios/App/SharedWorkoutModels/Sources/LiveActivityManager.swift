import Foundation
import ActivityKit
import os

private let logger = Logger(subsystem: "com.overload.fitnessapp", category: "LiveActivityManager")

@available(iOS 16.1, *)
public final class LiveActivityManager: @unchecked Sendable {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>? = nil
    private let lock = NSLock()

    private init() {}

    public func isSupported() -> Bool {
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        logger.info("ActivityAuthorizationInfo.areActivitiesEnabled: \(enabled)")
        return enabled
    }

    public func syncWorkoutState(_ state: WorkoutActivityAttributes.ContentState) {
        guard isSupported() else {
            logger.warning("Live Activities are not supported or disabled by user")
            return
        }

        lock.lock()
        defer { lock.unlock() }

        let activeActivities = Activity<WorkoutActivityAttributes>.activities.filter { $0.activityState == .active }
        logger.info("Syncing state: set=\(state.setIndex), isResting=\(state.isResting), activeActivitiesCount=\(activeActivities.count)")

        if let existing = activeActivities.first {
            currentActivity = existing
            Task {
                if #available(iOS 16.2, *) {
                    await existing.update(ActivityContent(state: state, staleDate: nil))
                } else {
                    await existing.update(using: state)
                }
                logger.info("Updated existing Live Activity: \(existing.id)")
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
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
            self.currentActivity = activity
            logger.info("Successfully started new Live Activity: \(activity.id)")
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
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
        logger.info("Ended all Live Activities")
    }
}

