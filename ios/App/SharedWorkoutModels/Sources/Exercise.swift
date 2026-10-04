import Foundation

public enum WorkoutSplit: String, Codable, CaseIterable, Identifiable {
    case push = "PUSH"
    case pull = "PULL"
    case legs = "LEGS"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .push: return "Push (Chest / Shoulders / Triceps)"
        case .pull: return "Pull (Back / Rear Delts / Biceps)"
        case .legs: return "Legs (Quads / Hamstrings / Calves)"
        }
    }
}

public enum ExerciseCategory: String, Codable {
    case heavyCompound = "HEAVY_COMPOUND"
    case machineCompound = "MACHINE_COMPOUND"
    case isolation = "ISOLATION"
}

public enum EquipmentType: String, Codable {
    case machineLever = "MACHINE_LEVER"
    case cableStack = "CABLE_STACK"
    case barbell = "BARBELL"
    case dumbbell = "DUMBBELL"
    case bodyweightLoaded = "BODYWEIGHT_LOADED"
}

public struct Exercise: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var split: String
    public var category: ExerciseCategory
    public var equipmentType: EquipmentType
    public var unit: String
    public var microIncrement: Double
    public var increment: Double
    public var repWindowMin: Int
    public var repWindowMax: Int
    public var targetSets: Int
    public var activeSetsCount: Int
    public var isCalibrated: Bool
    public var e1RM: Double
    public var fatigueIndex: Double
    public var loads: [Double]
    public var weight: Double
    public var consecutiveSet3Failures: Int
    public var consecutiveStagnations: Int
    public var consecutivePromotions: Int
    public var sessionsSinceRecalibration: Int
    public var muscleGroup: String
    public var baseTareWeight: Double
    public var isAssisted: Bool
    public var minWeight: Double?
    public var maxWeight: Double?

    public init(
        id: String,
        name: String,
        split: String,
        category: ExerciseCategory = .machineCompound,
        equipmentType: EquipmentType = .machineLever,
        unit: String = "lbs",
        microIncrement: Double = 2.5,
        increment: Double = 2.5,
        repWindowMin: Int = 8,
        repWindowMax: Int = 12,
        targetSets: Int = 3,
        activeSetsCount: Int = 3,
        isCalibrated: Bool = true,
        e1RM: Double = 100.0,
        fatigueIndex: Double = 0.15,
        loads: [Double] = [100, 85, 65],
        weight: Double = 100,
        consecutiveSet3Failures: Int = 0,
        consecutiveStagnations: Int = 0,
        consecutivePromotions: Int = 0,
        sessionsSinceRecalibration: Int = 0,
        muscleGroup: String = "CHEST",
        baseTareWeight: Double = 0.0,
        isAssisted: Bool = false,
        minWeight: Double? = nil,
        maxWeight: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.split = split
        self.category = category
        self.equipmentType = equipmentType
        self.unit = unit
        self.microIncrement = microIncrement
        self.increment = increment
        self.repWindowMin = repWindowMin
        self.repWindowMax = repWindowMax
        self.targetSets = targetSets
        self.activeSetsCount = activeSetsCount
        self.isCalibrated = isCalibrated
        self.e1RM = e1RM
        self.fatigueIndex = fatigueIndex
        self.loads = loads
        self.weight = weight
        self.consecutiveSet3Failures = consecutiveSet3Failures
        self.consecutiveStagnations = consecutiveStagnations
        self.consecutivePromotions = consecutivePromotions
        self.sessionsSinceRecalibration = sessionsSinceRecalibration
        self.muscleGroup = muscleGroup
        self.baseTareWeight = baseTareWeight
        self.isAssisted = isAssisted
        self.minWeight = minWeight
        self.maxWeight = maxWeight
    }

    enum CodingKeys: String, CodingKey {
        case id, name, split, category, equipmentType, unit, microIncrement, increment
        case repWindowMin, repWindowMax, targetSets, activeSetsCount, isCalibrated
        case e1RM, fatigueIndex, loads, weight
        case consecutiveSet3Failures, consecutiveStagnations, consecutivePromotions
        case sessionsSinceRecalibration, muscleGroup, baseTareWeight, isAssisted
        case minWeight, maxWeight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        split = try container.decode(String.self, forKey: .split)
        
        if let cat = try? container.decode(ExerciseCategory.self, forKey: .category) {
            category = cat
        } else if let catStr = try? container.decode(String.self, forKey: .category) {
            category = ExerciseCategory(rawValue: catStr) ?? .machineCompound
        } else {
            category = .machineCompound
        }

        if let eq = try? container.decode(EquipmentType.self, forKey: .equipmentType) {
            equipmentType = eq
        } else if let eqStr = try? container.decode(String.self, forKey: .equipmentType) {
            equipmentType = EquipmentType(rawValue: eqStr) ?? .machineLever
        } else {
            equipmentType = .machineLever
        }

        unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "lbs"
        microIncrement = try container.decodeIfPresent(Double.self, forKey: .microIncrement) ?? 2.5
        increment = try container.decodeIfPresent(Double.self, forKey: .increment) ?? 2.5
        repWindowMin = try container.decodeIfPresent(Int.self, forKey: .repWindowMin) ?? 8
        repWindowMax = try container.decodeIfPresent(Int.self, forKey: .repWindowMax) ?? 12
        targetSets = try container.decodeIfPresent(Int.self, forKey: .targetSets) ?? 3
        activeSetsCount = try container.decodeIfPresent(Int.self, forKey: .activeSetsCount) ?? 3
        isCalibrated = try container.decodeIfPresent(Bool.self, forKey: .isCalibrated) ?? true
        e1RM = try container.decodeIfPresent(Double.self, forKey: .e1RM) ?? 100.0
        fatigueIndex = try container.decodeIfPresent(Double.self, forKey: .fatigueIndex) ?? 0.15
        loads = try container.decodeIfPresent([Double].self, forKey: .loads) ?? [100.0, 85.0, 65.0]
        weight = try container.decodeIfPresent(Double.self, forKey: .weight) ?? (loads.first ?? 100.0)
        consecutiveSet3Failures = try container.decodeIfPresent(Int.self, forKey: .consecutiveSet3Failures) ?? 0
        consecutiveStagnations = try container.decodeIfPresent(Int.self, forKey: .consecutiveStagnations) ?? 0
        consecutivePromotions = try container.decodeIfPresent(Int.self, forKey: .consecutivePromotions) ?? 0
        sessionsSinceRecalibration = try container.decodeIfPresent(Int.self, forKey: .sessionsSinceRecalibration) ?? 0
        muscleGroup = try container.decodeIfPresent(String.self, forKey: .muscleGroup) ?? "CHEST"
        baseTareWeight = try container.decodeIfPresent(Double.self, forKey: .baseTareWeight) ?? 0.0
        isAssisted = try container.decodeIfPresent(Bool.self, forKey: .isAssisted) ?? false
        minWeight = try container.decodeIfPresent(Double.self, forKey: .minWeight)
        maxWeight = try container.decodeIfPresent(Double.self, forKey: .maxWeight)
    }
}
