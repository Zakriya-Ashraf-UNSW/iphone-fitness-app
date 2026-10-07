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

public struct MissedRepsOutcome: Codable, Hashable {
    public var loads: [Double]
    public var activeSetsCount: Int
    public var consecutiveFailures: Int
    public var extraSeconds: Int
    public var summary: String

    public init(loads: [Double], activeSetsCount: Int, consecutiveFailures: Int, extraSeconds: Int = 0, summary: String) {
        self.loads = loads
        self.activeSetsCount = activeSetsCount
        self.consecutiveFailures = consecutiveFailures
        self.extraSeconds = extraSeconds
        self.summary = summary
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

    // MARK: - Set 3 Parameter Resolution

    public static func resolveSet3Parameters(exercise: Exercise, pacingMode: String = "FAST_PACED") -> Set3Resolution {
        return resolveSet3Parameters(
            loads: exercise.loads,
            category: exercise.category,
            microIncrement: exercise.microIncrement,
            fatigueIndex: exercise.fatigueIndex,
            pacingMode: pacingMode,
            isAssisted: exercise.isAssisted,
            minWeight: exercise.minWeight,
            maxWeight: exercise.maxWeight
        )
    }

    public static func resolveSet3Parameters(
        loads: [Double],
        category: ExerciseCategory,
        microIncrement: Double,
        fatigueIndex: Double,
        pacingMode: String = "FAST_PACED",
        isAssisted: Bool = false,
        minWeight: Double? = nil,
        maxWeight: Double? = nil
    ) -> Set3Resolution {
        let limits = restLimits[category] ?? RestLimit(min: 120, defaultSec: 150, max: 180)
        let step = microIncrement > 0 ? microIncrement : 2.5
        let minW = minWeight ?? (isAssisted ? 5.0 : 0.0)
        let maxW = maxWeight ?? (isAssisted ? 50.0 : Double.infinity)

        let targetRest = (pacingMode == "FAST_PACED") ? (limits.minSeconds + 15) : limits.defaultSeconds
        var clampedRest = min(targetRest, limits.maxSeconds)
        var loadDropped = false
        var limitReached = false
        var prescribedW3: Double = 0.0

        let w1 = loads.first ?? 50.0
        let w3Current = loads.count > 2 ? loads[2] : w1

        if isAssisted {
            var candidateW3 = w3Current
            if clampedRest <= limits.defaultSeconds && fatigueIndex > 0.20 {
                if (candidateW3 + step) <= maxW {
                    candidateW3 += step
                    loadDropped = true
                } else {
                    limitReached = true
                }
            }
            prescribedW3 = min(maxW, max(w1, candidateW3))
            if prescribedW3 >= maxW { limitReached = true }
            if limitReached {
                clampedRest = min(limits.maxSeconds + 60, clampedRest + 60)
            }
        } else {
            let floorW3 = max(minW, roundToStep(w1 * 0.60, step: step))
            var candidateW3 = max(minW, w3Current)
            if clampedRest <= limits.defaultSeconds && fatigueIndex > 0.20 {
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

    // MARK: - Progression Evaluation

    public static func evaluateProgression(exercise: Exercise, repsCompleted: [Int]) -> ProgressionOutcome {
        return evaluateProgression(
            loads: exercise.loads,
            reps: repsCompleted,
            activeSetsCount: exercise.activeSetsCount,
            repMax: exercise.repWindowMax,
            microIncrement: exercise.microIncrement,
            unit: exercise.unit,
            isAssisted: exercise.isAssisted,
            minWeight: exercise.minWeight,
            maxWeight: exercise.maxWeight
        )
    }

    public static func evaluateProgression(
        loads: [Double],
        reps: [Int],
        activeSetsCount: Int,
        repMax: Int,
        microIncrement: Double,
        unit: String = "kg",
        isAssisted: Bool = false,
        minWeight: Double? = nil,
        maxWeight: Double? = nil
    ) -> ProgressionOutcome {
        var l = loads
        while l.count < 3 { l.append(l.last ?? 50.0) }
        var w1 = l[0]
        var w2 = l[1]
        var w3 = l[2]

        let r1 = reps.indices.contains(0) ? reps[0] : 0
        let r2 = reps.indices.contains(1) ? reps[1] : 0
        let r3 = reps.indices.contains(2) ? reps[2] : 0

        let step = microIncrement > 0 ? microIncrement : 2.5
        let minW = minWeight ?? (isAssisted ? 5.0 : 0.0)
        let maxW = maxWeight ?? (isAssisted ? 50.0 : Double.infinity)

        var s1Adv = false
        var s2Adv = false
        var s3Adv = false
        var s1HeldReason: String? = nil

        if isAssisted {
            if activeSetsCount == 3 && r3 >= repMax {
                if (w3 - step) >= w2 {
                    w3 = max(minW, w3 - step)
                    s3Adv = true
                }
            }
            if r2 >= repMax {
                if (w2 - step) >= w1 {
                    w2 = max(minW, w2 - step)
                    s2Adv = true
                }
            }
            if r1 >= repMax {
                if w1 <= minW {
                    s1HeldReason = "Machine Lowest Assistance reached! Ready for Unassisted Bodyweight!"
                } else if w2 <= (w1 + step) {
                    w1 = max(minW, w1 - step)
                    s1Adv = true
                } else {
                    s1HeldReason = "Set 2 assistance must work down closer to Set 1"
                }
            }
            w1 = min(maxW, max(minW, w1))
            w2 = min(maxW, max(w1, w2))
            if activeSetsCount == 3 {
                w3 = min(maxW, max(w2, w3))
            }
            let summary = s1Adv ? "🎉 Anchor Promotion: Next Set 1 Assistance reduced to \(w1) \(unit)" : (s2Adv || s3Adv ? "Set Progression: Next loads consolidated" : "Working Loads Held")
            return ProgressionOutcome(loads: [w1, w2, w3], s1Adv: s1Adv, s2Adv: s2Adv, s3Adv: s3Adv, s1HeldReason: s1HeldReason, summary: summary)
        }

        // Standard Progression
        if activeSetsCount == 3 {
            if r3 >= repMax {
                if (w3 + step) <= w2 {
                    w3 += step
                    s3Adv = true
                }
            }
            if r2 >= repMax {
                if (w2 + step) <= w1 {
                    w2 += step
                    s2Adv = true
                }
            }
            let set2Consolidated = (w2 >= (w1 * 0.85 - 0.001))
            let set3Consolidated = (w3 >= (w1 * 0.65 - 0.001))
            if r1 >= repMax {
                if set2Consolidated && set3Consolidated {
                    w1 += step
                    s1Adv = true
                } else {
                    if !set2Consolidated {
                        s1HeldReason = "Set 2 (\(w2)) must reach ≥ 85% of Set 1 (\(roundToStep(w1 * 0.85, step: step)) \(unit))"
                    } else {
                        s1HeldReason = "Set 3 (\(w3)) must reach ≥ 65% of Set 1 (\(roundToStep(w1 * 0.65, step: step)) \(unit))"
                    }
                }
            }
            w2 = max(minW, max(w2, roundToStep(w1 * 0.80, step: step)))
            w3 = max(minW, max(w3, roundToStep(w1 * 0.60, step: step)))
        } else {
            if r2 >= repMax {
                if (w2 + step) <= w1 {
                    w2 += step
                    s2Adv = true
                }
            }
            let set2Consolidated = (w2 >= (w1 * 0.85 - 0.001))
            if r1 >= repMax {
                if set2Consolidated {
                    w1 += step
                    s1Adv = true
                } else {
                    s1HeldReason = "Set 2 (\(w2)) must reach ≥ 85% of Set 1 (\(roundToStep(w1 * 0.85, step: step)) \(unit))"
                }
            }
            w2 = max(minW, max(w2, roundToStep(w1 * 0.80, step: step)))
        }

        let summary = s1Adv ? "🎉 Anchor Promotion: Next Set 1 increased to \(w1) \(unit) (+\(step))" : (s2Adv || s3Adv ? "Volume Advancement: Secondary load incremented" : "Working Load Consolidated")
        return ProgressionOutcome(loads: [w1, w2, w3], s1Adv: s1Adv, s2Adv: s2Adv, s3Adv: s3Adv, s1HeldReason: s1HeldReason, summary: summary)
    }

    // MARK: - Missed Reps & Drop Handling (SPEC-001 §5.4)

    public static func handleMissedReps(
        loads: [Double],
        reps: [Int],
        activeSetsCount: Int,
        repMin: Int,
        microIncrement: Double,
        consecutiveFailures: Int = 0
    ) -> MissedRepsOutcome {
        var l = loads
        while l.count < 3 { l.append(l.last ?? 50.0) }
        var w1 = l[0]
        var w2 = l[1]
        var w3 = l[2]

        let r1 = reps.indices.contains(0) ? reps[0] : 0
        let r2 = reps.indices.contains(1) ? reps[1] : 0
        let r3 = reps.indices.contains(2) ? reps[2] : 0
        let s = microIncrement > 0 ? microIncrement : 2.5

        // Branch 1: Set 1 Failed
        if r1 < repMin {
            w1 = max(s, w1 - s)
            w2 = min(w2, w1)
            w3 = min(w3, w2)
            return MissedRepsOutcome(
                loads: [w1, w2, w3],
                activeSetsCount: activeSetsCount,
                consecutiveFailures: consecutiveFailures,
                summary: "Set 1 missed threshold (< \(repMin)r). Anchor load deloaded by -\(s)."
            )
        }

        // Branch 2: Set 2 Failed
        if r2 < repMin {
            let floor2 = roundToStep(w1 * 0.80, step: s)
            if (w2 - s) >= floor2 {
                w2 -= s
                w3 = min(w3, w2)
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: activeSetsCount,
                    consecutiveFailures: consecutiveFailures,
                    summary: "Set 2 missed threshold (< \(repMin)r). Intermediate load dropped by -\(s)."
                )
            } else {
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: activeSetsCount,
                    consecutiveFailures: consecutiveFailures,
                    extraSeconds: 60,
                    summary: "Set 2 reached 80% floor. Load held, +60s rest added."
                )
            }
        }

        // Branch 3: Set 3 Failed (3-set mode)
        if activeSetsCount == 3 && r3 < repMin {
            let floor3 = roundToStep(w1 * 0.60, step: s)
            if (w3 - s) >= floor3 {
                w3 -= s
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: 3,
                    consecutiveFailures: 0,
                    summary: "Set 3 missed threshold. Base load dropped by -\(s)."
                )
            } else {
                // 60% floor breach
                if consecutiveFailures >= 1 {
                    return MissedRepsOutcome(
                        loads: [w1, w2, w3],
                        activeSetsCount: 2,
                        consecutiveFailures: 0,
                        summary: "Consecutive 60% floor breach! Dropped to 2-Set Mode to recover capacity."
                    )
                } else {
                    return MissedRepsOutcome(
                        loads: [w1, w2, w3],
                        activeSetsCount: 3,
                        consecutiveFailures: 1,
                        extraSeconds: 60,
                        summary: "Set 3 hit 60% floor. Consecutive failure warning logged, +60s rest added."
                    )
                }
            }
        }

        return MissedRepsOutcome(
            loads: [w1, w2, w3],
            activeSetsCount: activeSetsCount,
            consecutiveFailures: consecutiveFailures,
            summary: "Loads maintained."
        )
    }
}
