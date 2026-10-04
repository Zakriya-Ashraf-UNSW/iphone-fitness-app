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
        public var isRecap: Bool                  // true when lift is completed, showing progression recap
        public var recapLoggedSetsText: String   // e.g. "S1: 10r • S2: 9r • S3: 8r"
        public var recapProgressionHeadline: String // e.g. "OVERLOAD BREAKTHROUGH"
        public var recapNextTargetText: String   // e.g. "Next Anchor: 22.5 KG (+2.5 KG)"
        public var recapIsFinalExercise: Bool    // true if final exercise of workout

        // Warm-up & Transition State
        public var isWarmup: Bool                // true when executing prescribed warm-up sets
        public var warmupIndex: Int              // e.g. 1 (for W1)
        public var totalWarmups: Int             // e.g. 3 (for 3 warmup sets)
        public var warmupTargetText: String      // e.g. "10 reps @ 60.0 KG (50% Prep)"
        public var isTransitionRest: Bool        // true during automatic inter-exercise rest countdown
        public var nextExerciseName: String      // e.g. "Incline Dumbbell Press"

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
            overloadIncrementText: String = "+5 lbs Next",
            isRecap: Bool = false,
            recapLoggedSetsText: String = "",
            recapProgressionHeadline: String = "",
            recapNextTargetText: String = "",
            recapIsFinalExercise: Bool = false,
            isWarmup: Bool = false,
            warmupIndex: Int = 1,
            totalWarmups: Int = 0,
            warmupTargetText: String = "",
            isTransitionRest: Bool = false,
            nextExerciseName: String = ""
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
            self.isRecap = isRecap
            self.recapLoggedSetsText = recapLoggedSetsText
            self.recapProgressionHeadline = recapProgressionHeadline
            self.recapNextTargetText = recapNextTargetText
            self.recapIsFinalExercise = recapIsFinalExercise
            self.isWarmup = isWarmup
            self.warmupIndex = warmupIndex
            self.totalWarmups = totalWarmups
            self.warmupTargetText = warmupTargetText
            self.isTransitionRest = isTransitionRest
            self.nextExerciseName = nextExerciseName
        }
    }

    public var workoutId: String

    public init(workoutId: String = "overload-session") {
        self.workoutId = workoutId
    }
}
