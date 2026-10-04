import Foundation

public struct RestLimit {
    public var minSeconds: Int
    public var defaultSeconds: Int
    public var maxSeconds: Int
    
    public init(min: Int, defaultSec: Int, max: Int) {
        self.minSeconds = min
        self.defaultSeconds = defaultSec
        self.maxSeconds = max
    }
}

public struct ProgressionOutcome: Codable, Hashable {
    public var loads: [Double]
    public var s1Adv: Bool
    public var s2Adv: Bool
    public var s3Adv: Bool
    public var s1HeldReason: String?
    public var summary: String
    
    public init(loads: [Double], s1Adv: Bool, s2Adv: Bool, s3Adv: Bool, s1HeldReason: String?, summary: String) {
        self.loads = loads
        self.s1Adv = s1Adv
        self.s2Adv = s2Adv
        self.s3Adv = s3Adv
        self.s1HeldReason = s1HeldReason
        self.summary = summary
    }
}

public struct Set3Resolution: Codable, Hashable {
    public var restTimerSeconds: Int
    public var prescribedLoad: Double
    public var loadDroppedForFatigue: Bool
    public var minLimitReached: Bool

    public init(restTimerSeconds: Int, prescribedLoad: Double, loadDroppedForFatigue: Bool, minLimitReached: Bool) {
        self.restTimerSeconds = restTimerSeconds
        self.prescribedLoad = prescribedLoad
        self.loadDroppedForFatigue = loadDroppedForFatigue
        self.minLimitReached = minLimitReached
    }
}

public enum DPOEngine {
    public static let restLimits: [ExerciseCategory: RestLimit] = [
        .heavyCompound: RestLimit(min: 150, defaultSec: 180, max: 240),
        .machineCompound: RestLimit(min: 120, defaultSec: 150, max: 180),
        .isolation: RestLimit(min: 90, defaultSec: 120, max: 150)
    ]

    public static func roundToStep(_ value: Double, step: Double) -> Double {
        let s = step > 0 ? step : 2.5
        return (value / s).rounded() * s
    }

    public static func calculateE1RM(load: Double, reps: Double) -> Double {
        if reps <= 0 || load <= 0 { return load }
        let raw = load * (1.0 + (reps / 30.0))
        return (raw * 10.0).rounded() / 10.0
    }

    public static func calculateFatigueIndex(e1RM: Double, w2: Double, r2Actual: Double) -> Double {
        guard w2 > 0, e1RM > 0 else { return 0.0 }
        let r2Expected = 30.0 * ((e1RM / w2) - 1.0)
        guard r2Expected > 0 else { return 0.0 }
        let rawFI = 1.0 - (r2Actual / r2Expected)
        return max(0.0, min(1.0, (rawFI * 1000.0).rounded() / 1000.0))
    }

    public static func calculatePredictedReps(e1RM: Double, load: Double) -> Int {
        guard load > 0, e1RM > 0 else { return 0 }
        return Int((30.0 * ((e1RM / load) - 1.0)).rounded())
    }

    public static func resolveSet3Parameters(exercise: Exercise, pacingMode: String = "FAST_PACED") -> Set3Resolution {
        let limits = restLimits[exercise.category] ?? RestLimit(min: 120, defaultSec: 150, max: 180)
        let step = exercise.microIncrement > 0 ? exercise.microIncrement : 2.5
        let minW = exercise.minWeight ?? (exercise.isAssisted ? 5.0 : 0.0)
        let maxW = exercise.maxWeight ?? (exercise.isAssisted ? (exercise.unit.lowercased() == "kg" ? 50.0 : 100.0) : Double.infinity)

        let targetRest = (pacingMode == "FAST_PACED") ? (limits.minSeconds + 15) : limits.defaultSeconds
        var clampedRest = min(targetRest, limits.maxSeconds)
        var loadDropped = false
        var limitReached = false
        var prescribedW3: Double = 0.0

        if exercise.isAssisted {
            var candidateW3 = exercise.loads.count > 2 ? exercise.loads[2] : exercise.weight
            if clampedRest <= limits.defaultSeconds && exercise.fatigueIndex > 0.20 {
                if (candidateW3 + step) <= maxW {
                    candidateW3 += step
                    loadDropped = true
                } else {
                    limitReached = true
                }
            }
            prescribedW3 = min(maxW, max(exercise.loads.first ?? 0, candidateW3))
            if prescribedW3 >= maxW { limitReached = true }
            if limitReached {
                clampedRest = min(limits.maxSeconds + 60, clampedRest + 60)
            }
        } else {
            let floorW3 = max(minW, roundToStep((exercise.loads.first ?? exercise.weight) * 0.60, step: step))
            var candidateW3 = max(minW, exercise.loads.count > 2 ? exercise.loads[2] : exercise.weight)
            if clampedRest <= limits.defaultSeconds && exercise.fatigueIndex > 0.20 {
                if (candidateW3 - step) >= minW {
                    candidateW3 = max(floorW3, candidateW3 - step)
                    loadDropped = true
                } else {
                    limitReached = true
                }
            }
            prescribedW3 = max(floorW3, candidateW3)
            if prescribedW3 <= minW { limitReached = true }
            if limitReached {
                clampedRest = min(limits.maxSeconds + 60, clampedRest + 60)
            }
        }

        return Set3Resolution(
            restTimerSeconds: clampedRest,
            prescribedLoad: prescribedW3,
            loadDroppedForFatigue: loadDropped,
            minLimitReached: limitReached
        )
    }

    public static func evaluateProgression(exercise: Exercise, repsCompleted: [Int]) -> ProgressionOutcome {
        var loads = exercise.loads
        while loads.count < 3 { loads.append(loads.last ?? exercise.weight) }
        var w1 = loads[0]
        var w2 = loads[1]
        var w3 = loads[2]

        let r1 = repsCompleted.indices.contains(0) ? repsCompleted[0] : 0
        let r2 = repsCompleted.indices.contains(1) ? repsCompleted[1] : 0
        let r3 = repsCompleted.indices.contains(2) ? repsCompleted[2] : 0

        let step = exercise.microIncrement > 0 ? exercise.microIncrement : 2.5
        let rMax = exercise.repWindowMax
        let minW = exercise.minWeight ?? (exercise.isAssisted ? 5.0 : 0.0)
        let maxW = exercise.maxWeight ?? (exercise.isAssisted ? (exercise.unit.lowercased() == "kg" ? 50.0 : 100.0) : Double.infinity)

        var s1Adv = false
        var s2Adv = false
        var s3Adv = false
        var s1HeldReason: String? = nil

        if exercise.isAssisted {
            if exercise.activeSetsCount == 3 && r3 >= rMax {
                if (w3 - step) >= w2 {
                    w3 = max(minW, w3 - step)
                    s3Adv = true
                }
            }
            if r2 >= rMax {
                if (w2 - step) >= w1 {
                    w2 = max(minW, w2 - step)
                    s2Adv = true
                }
            }
            if r1 >= rMax {
                if w1 <= minW {
                    s1HeldReason = "Machine Lowest Assistance (\(minW) \(exercise.unit)) reached! Ready for Unassisted Bodyweight!"
                } else if w2 <= (w1 + step) {
                    w1 = max(minW, w1 - step)
                    s1Adv = true
                } else {
                    s1HeldReason = "Set 2 assistance (\(w2)) must work down closer to Set 1 (\(w1) \(exercise.unit))"
                }
            }
            w1 = min(maxW, max(minW, w1))
            w2 = min(maxW, max(w1, w2))
            if exercise.activeSetsCount == 3 {
                w3 = min(maxW, max(w2, w3))
            }
            let summary = s1Adv ? "🎉 Anchor Promotion: Next Set 1 Assistance reduced to \(w1) \(exercise.unit)" : (s2Adv || s3Adv ? "Set Progression: Next loads consolidated" : "Working Loads Held")
            return ProgressionOutcome(loads: [w1, w2, w3], s1Adv: s1Adv, s2Adv: s2Adv, s3Adv: s3Adv, s1HeldReason: s1HeldReason, summary: summary)
        }

        // Standard Progression
        if exercise.activeSetsCount == 3 {
            if r3 >= rMax {
                if (w3 + step) <= w2 {
                    w3 += step
                    s3Adv = true
                }
            }
            if r2 >= rMax {
                if (w2 + step) <= w1 {
                    w2 += step
                    s2Adv = true
                }
            }
            let set2Consolidated = (w2 >= (w1 * 0.85 - 0.001))
            let set3Consolidated = (w3 >= (w1 * 0.65 - 0.001))
            if r1 >= rMax {
                if set2Consolidated && set3Consolidated {
                    w1 += step
                    s1Adv = true
                } else {
                    if !set2Consolidated {
                        s1HeldReason = "Set 2 (\(w2)) must reach ≥ 85% of Set 1 (\(roundToStep(w1 * 0.85, step: step)) \(exercise.unit))"
                    } else {
                        s1HeldReason = "Set 3 (\(w3)) must reach ≥ 65% of Set 1 (\(roundToStep(w1 * 0.65, step: step)) \(exercise.unit))"
                    }
                }
            }
            w2 = max(minW, max(w2, roundToStep(w1 * 0.80, step: step)))
            w3 = max(minW, max(w3, roundToStep(w1 * 0.60, step: step)))
        } else {
            if r2 >= rMax {
                if (w2 + step) <= w1 {
                    w2 += step
                    s2Adv = true
                }
            }
            let set2Consolidated = (w2 >= (w1 * 0.85 - 0.001))
            if r1 >= rMax {
                if set2Consolidated {
                    w1 += step
                    s1Adv = true
                } else {
                    s1HeldReason = "Set 2 (\(w2)) must reach ≥ 85% of Set 1 (\(roundToStep(w1 * 0.85, step: step)) \(exercise.unit))"
                }
            }
            w2 = max(minW, max(w2, roundToStep(w1 * 0.80, step: step)))
        }

        let summary = s1Adv ? "🎉 Anchor Promotion: Next Set 1 increased to \(w1) \(exercise.unit) (+\(step))" : (s2Adv || s3Adv ? "Volume Advancement: Secondary load incremented" : "Working Load Consolidated")
        return ProgressionOutcome(loads: [w1, w2, w3], s1Adv: s1Adv, s2Adv: s2Adv, s3Adv: s3Adv, s1HeldReason: s1HeldReason, summary: summary)
    }
}
