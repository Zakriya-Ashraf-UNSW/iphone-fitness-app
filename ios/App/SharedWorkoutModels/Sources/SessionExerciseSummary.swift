import Foundation

public struct SessionExerciseSummary: Identifiable, Codable, Equatable {
    public let id: UUID
    public let exerciseId: String
    public let exerciseName: String
    public let muscleGroup: String
    public let split: String
    public let unit: String
    public let targetSets: Int
    public let loggedReps: [Int]
    public let loadsUsed: [Double]
    public let nextLoads: [Double]
    public let deltas: [Double]
    public let progressionSummary: String
    public let isAnchorPromoted: Bool
    public let isAssisted: Bool

    public init(
        id: UUID = UUID(),
        exerciseId: String,
        exerciseName: String,
        muscleGroup: String,
        split: String,
        unit: String,
        targetSets: Int,
        loggedReps: [Int],
        loadsUsed: [Double],
        nextLoads: [Double],
        deltas: [Double],
        progressionSummary: String,
        isAnchorPromoted: Bool,
        isAssisted: Bool = false
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.split = split
        self.unit = unit
        self.targetSets = targetSets
        self.loggedReps = loggedReps
        self.loadsUsed = loadsUsed
        self.nextLoads = nextLoads
        self.deltas = deltas
        self.progressionSummary = progressionSummary
        self.isAnchorPromoted = isAnchorPromoted
        self.isAssisted = isAssisted
    }
}
