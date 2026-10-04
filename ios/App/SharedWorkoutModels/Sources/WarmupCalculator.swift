import Foundation

public struct WarmupSet: Codable, Identifiable, Hashable {
    public var id: Int { setIndex }
    public var setIndex: Int
    public var targetReps: Int
    public var load: Double
    public var restSeconds: Int
    public var pct: String

    public init(setIndex: Int, targetReps: Int, load: Double, restSeconds: Int, pct: String) {
        self.setIndex = setIndex
        self.targetReps = targetReps
        self.load = load
        self.restSeconds = restSeconds
        self.pct = pct
    }
}

public struct WarmupPrescription: Codable, Hashable {
    public var tier: String
    public var warmups: [WarmupSet]
    public var reason: String

    public init(tier: String, warmups: [WarmupSet], reason: String) {
        self.tier = tier
        self.warmups = warmups
        self.reason = reason
    }
}

public enum WarmupCalculator {
    public static func roundToStep(_ value: Double, step: Double) -> Double {
        let s = step > 0 ? step : 2.5
        return (value / s).rounded() * s
    }

    public static func getBaseTareWeight(for exercise: Exercise) -> Double {
        if exercise.baseTareWeight > 0 { return exercise.baseTareWeight }
        let isKg = exercise.unit.lowercased() == "kg"
        switch exercise.equipmentType {
        case .barbell: return isKg ? 20.0 : 45.0
        case .dumbbell: return isKg ? 2.0 : 5.0
        case .cableStack: return isKg ? 2.5 : 5.0
        case .machineLever, .bodyweightLoaded: return 0.0
        }
    }

    public static func resolveWarmupTier(exercise: Exercise, previousMuscleGroupsWorked: [String]) -> String {
        let muscle = exercise.muscleGroup.uppercased()
        let isFirstForMuscle = !previousMuscleGroupsWorked.contains(muscle)

        switch exercise.category {
        case .heavyCompound, .machineCompound:
            return isFirstForMuscle ? "FULL_RAMP" : "ACCUSTOMED"
        case .isolation:
            return isFirstForMuscle ? "PRIMING" : "NONE"
        }
    }

    public static func generateWarmupPrescription(exercise: Exercise, previousMuscleGroupsWorked: [String]) -> WarmupPrescription {
        let w1 = exercise.loads.first ?? exercise.weight
        let step = exercise.microIncrement > 0 ? exercise.microIncrement : 2.5
        let minTare = getBaseTareWeight(for: exercise)
        let tier = resolveWarmupTier(exercise: exercise, previousMuscleGroupsWorked: previousMuscleGroupsWorked)
        var warmups: [WarmupSet] = []

        if exercise.isAssisted {
            let maxW = exercise.maxWeight ?? (exercise.unit.lowercased() == "kg" ? 50.0 : 100.0)
            let p1 = min(maxW, roundToStep(w1 * 1.50, step: step))
            let p2 = min(maxW, roundToStep(w1 * 1.25, step: step))
            if p1 > w1 {
                warmups.append(WarmupSet(setIndex: 1, targetReps: 8, load: p1, restSeconds: 60, pct: "+50% Assist"))
            }
            if p2 > w1 && p2 < p1 {
                warmups.append(WarmupSet(setIndex: 2, targetReps: 4, load: p2, restSeconds: 75, pct: "+25% Assist"))
            }
            return WarmupPrescription(
                tier: "ASSISTED_RAMP",
                warmups: warmups,
                reason: "Warm-up with higher assistance counterweight before tackling anchor pin (\(w1) \(exercise.unit))."
            )
        }

        let threshold: Double = exercise.unit.lowercased() == "kg" ? 15.0 : 35.0
        if w1 <= threshold || tier == "NONE" {
            let reason = (w1 <= threshold)
                ? "Anchor W1 (\(w1) \(exercise.unit) ≤ \(threshold) \(exercise.unit)) below warm-up threshold."
                : "Muscle (\(exercise.muscleGroup)) already fatigued/warmed. No warm-ups needed."
            return WarmupPrescription(tier: tier, warmups: [], reason: reason)
        }

        if tier == "FULL_RAMP" {
            let p1 = max(minTare, roundToStep(w1 * 0.50, step: step))
            let p2 = max(p1 + step, roundToStep(w1 * 0.70, step: step))
            let p3 = max(p2 + step, roundToStep(w1 * 0.875, step: step))

            if p1 < w1 {
                warmups.append(WarmupSet(setIndex: 1, targetReps: 10, load: p1, restSeconds: 60, pct: "50%"))
            }
            if p2 < w1 && p2 > p1 {
                warmups.append(WarmupSet(setIndex: 2, targetReps: 4, load: p2, restSeconds: 75, pct: "70%"))
            }
            if p3 < w1 && p3 > p2 {
                warmups.append(WarmupSet(setIndex: 3, targetReps: 1, load: p3, restSeconds: 90, pct: "87.5%"))
            }
        } else if tier == "ACCUSTOMED" {
            let p1 = max(minTare, roundToStep(w1 * 0.60, step: step))
            let p2 = max(p1 + step, roundToStep(w1 * 0.85, step: step))

            if p1 < w1 {
                warmups.append(WarmupSet(setIndex: 1, targetReps: 6, load: p1, restSeconds: 60, pct: "60%"))
            }
            if p2 < w1 && p2 > p1 {
                warmups.append(WarmupSet(setIndex: 2, targetReps: 2, load: p2, restSeconds: 75, pct: "85%"))
            }
        } else if tier == "PRIMING" {
            let p1 = max(minTare, roundToStep(w1 * 0.60, step: step))
            if p1 < w1 {
                warmups.append(WarmupSet(setIndex: 1, targetReps: 8, load: p1, restSeconds: 45, pct: "60%"))
            }
        }

        let validWarmups = warmups.filter { $0.load < w1 && $0.load >= minTare }
        var reason = ""
        if tier == "FULL_RAMP" {
            reason = "Primary Compound (\(exercise.muscleGroup)): 3 Neural Potentiation Sets (≥4 RIR). Load strictly < W1."
        } else if tier == "ACCUSTOMED" {
            reason = "Subsequent Compound (\(exercise.muscleGroup)): 2 Priming Sets. Joint & friction prep."
        } else if tier == "PRIMING" {
            reason = "First Isolation (\(exercise.muscleGroup)): 1 Line-of-pull priming set (60%)."
        }

        return WarmupPrescription(tier: tier, warmups: validWarmups, reason: reason)
    }
}
