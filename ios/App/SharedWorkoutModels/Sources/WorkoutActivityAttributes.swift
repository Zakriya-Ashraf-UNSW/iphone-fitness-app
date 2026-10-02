import ActivityKit
import Foundation

public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var splitName: String              // e.g. "PUSH", "PULL", "LEGS"
        public var exerciseName: String           // e.g. "Smith Incline"
        public var setIndex: Int                  // e.g. 2
        public var totalSets: Int                 // e.g. 3
        public var loadText: String               // e.g. "115.0 LBS"
        public var targetRepsText: String         // e.g. "8-12 Reps"
        public var isResting: Bool                // true during rest countdown
        public var restEndTimestamp: TimeInterval? // Target epoch time in seconds
        public var isTriageLogging: Bool          // true when set completed, awaiting 1-tap triage
        public var underTargetText: String        // e.g. "< 8 Missed"
        public var prescribedTargetText: String   // e.g. "8-11 Target"
        public var overloadTargetText: String     // e.g. "12+ Overload"
        public var overloadIncrementText: String  // e.g. "+5 lbs Next"

        public init(
            splitName: String = "PUSH",
            exerciseName: String = "Smith Incline",
            setIndex: Int = 2,
            totalSets: Int = 3,
            loadText: String = "115.0 LBS",
            targetRepsText: String = "8-12 Reps",
            isResting: Bool = true,
            restEndTimestamp: TimeInterval? = nil,
            isTriageLogging: Bool = false,
            underTargetText: String = "< 8 Missed",
            prescribedTargetText: String = "8-11 Target",
            overloadTargetText: String = "12+ Overload",
            overloadIncrementText: String = "+5 lbs Next"
        ) {
            self.splitName = splitName
            self.exerciseName = exerciseName
            self.setIndex = setIndex
            self.totalSets = totalSets
            self.loadText = loadText
            self.targetRepsText = targetRepsText
            self.isResting = isResting
            self.restEndTimestamp = restEndTimestamp
            self.isTriageLogging = isTriageLogging
            self.underTargetText = underTargetText
            self.prescribedTargetText = prescribedTargetText
            self.overloadTargetText = overloadTargetText
            self.overloadIncrementText = overloadIncrementText
        }
    }

    public var workoutId: String

    public init(workoutId: String = "overload-session") {
        self.workoutId = workoutId
    }
}
