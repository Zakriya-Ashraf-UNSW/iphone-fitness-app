import Foundation

public struct WorkoutHistoryEntry: Codable, Identifiable, Hashable {
    public var id: String
    public var exerciseId: String
    public var exerciseName: String
    public var split: String
    public var unit: String
    public var targetSets: Int
    public var loadsUsed: [Double]
    public var nextLoads: [Double]
    public var weightUsed: Double
    public var nextTargetWeight: Double
    public var increment: Double
    public var set1Reps: String
    public var set2Reps: String
    public var set3Reps: String
    public var fatigueIndex: Double
    public var e1RM: Double
    public var progressionSummary: String
    public var timestamp: String
    public var dateString: String

    public init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String,
        split: String,
        unit: String = "lbs",
        targetSets: Int = 3,
        loadsUsed: [Double],
        nextLoads: [Double],
        weightUsed: Double,
        nextTargetWeight: Double,
        increment: Double,
        set1Reps: String,
        set2Reps: String,
        set3Reps: String,
        fatigueIndex: Double,
        e1RM: Double,
        progressionSummary: String,
        timestamp: String = ISO8601DateFormatter().string(from: Date()),
        dateString: String = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.split = split
        self.unit = unit
        self.targetSets = targetSets
        self.loadsUsed = loadsUsed
        self.nextLoads = nextLoads
        self.weightUsed = weightUsed
        self.nextTargetWeight = nextTargetWeight
        self.increment = increment
        self.set1Reps = set1Reps
        self.set2Reps = set2Reps
        self.set3Reps = set3Reps
        self.fatigueIndex = fatigueIndex
        self.e1RM = e1RM
        self.progressionSummary = progressionSummary
        self.timestamp = timestamp
        self.dateString = dateString
    }
}
