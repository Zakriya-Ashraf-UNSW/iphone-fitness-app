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
        .heavyCompound: RestLimit(min: 120, defaultSec: 150, max: 180),
        .machineCompound: RestLimit(min: 75, defaultSec: 90, max: 120),
        .isolation: RestLimit(min: 45, defaultSec: 60, max: 90)
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

    // MARK: - Calibration Engine (SPEC-001 §5.1)

    public struct CalibrationResult: Codable, Hashable {
        public var e1RM: Double
        public var fatigueIndex: Double
        public var loads: [Double]
        public var activeSetsCount: Int

        public init(e1RM: Double, fatigueIndex: Double, loads: [Double], activeSetsCount: Int = 3) {
            self.e1RM = e1RM
            self.fatigueIndex = fatigueIndex
            self.loads = loads
            self.activeSetsCount = activeSetsCount
        }
    }

    public static func executeCalibration(
        set1Load: Double,
        set1Reps: Int,
        set2Load: Double,
        set2Reps: Int,
        microIncrement: Double,
        isAssisted: Bool = false,
        minWeight: Double? = nil,
        maxWeight: Double? = nil,
        unit: String = "lbs"
    ) -> CalibrationResult {
        let step = microIncrement > 0 ? microIncrement : 2.5
        let isKg = unit.lowercased() == "kg"
        let minW = minWeight ?? (isAssisted ? (isKg ? 2.5 : 5.0) : 0.0)
        let maxW = maxWeight ?? (isAssisted ? (isKg ? 50.0 : 100.0) : Double.infinity)

        if isAssisted {
            // Assisted exercise calibration (SPEC-001 §11: Counterweight Pin Tracking)
            let a1 = min(maxW, max(minW, set1Load))
            let rawFI: Double
            if set1Reps > 0 {
                let expectedReps = max(1.0, Double(set1Reps) * 0.9)
                rawFI = max(0.0, min(1.0, 1.0 - (Double(set2Reps) / expectedReps)))
            } else {
                rawFI = 0.15
            }
            let fi = max(0.0, min(1.0, (rawFI * 1000.0).rounded() / 1000.0))

            // Fatigue accommodation: Intermediate set requires +20% to +25% higher assistance pin
            var a2 = roundToStep(a1 * (1.20 + (fi * 0.20)), step: step)
            a2 = min(maxW, max(a1 + step, a2))

            // Base set requires +40% to +50% higher assistance pin
            var a3 = roundToStep(a1 * (1.40 + (fi * 0.40)), step: step)
            a3 = min(maxW, max(a2 + step, a3))

            let e1RM = (a1 * (1.0 + (Double(set1Reps) / 30.0)) * 10.0).rounded() / 10.0

            return CalibrationResult(
                e1RM: e1RM,
                fatigueIndex: fi,
                loads: [a1, a2, a3],
                activeSetsCount: 3
            )
        }

        let e1RM = set1Load * (1.0 + (Double(set1Reps) / 30.0))
        let r2Expected = 30.0 * ((e1RM / set2Load) - 1.0)
        let rawFI = (r2Expected > 0) ? (1.0 - (Double(set2Reps) / r2Expected)) : 0.0
        let fi = max(0.0, min(1.0, rawFI))

        let w1 = min(maxW, max(minW, set1Load))
        let w2Ratio = max(0.80, 1.0 - (fi * 0.5))
        let w3Ratio = max(0.60, 1.0 - (fi * 1.0))

        let w2 = min(maxW, max(minW, roundToStep(w1 * w2Ratio, step: step)))
        let w3 = min(maxW, max(minW, roundToStep(w1 * w3Ratio, step: step)))

        let roundedE1RM = (e1RM * 10.0).rounded() / 10.0
        let roundedFI = (fi * 1000.0).rounded() / 1000.0

        return CalibrationResult(
            e1RM: roundedE1RM,
            fatigueIndex: roundedFI,
            loads: [w1, w2, w3],
            activeSetsCount: 3
        )
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
                if (w3 + step) <= min(maxW, w2) {
                    w3 += step
                    s3Adv = true
                }
            }
            if r2 >= repMax {
                if (w2 + step) <= min(maxW, w1) {
                    w2 += step
                    s2Adv = true
                }
            }
            let set2Consolidated = (w2 >= (w1 * 0.85 - 0.001))
            let set3Consolidated = (w3 >= (w1 * 0.65 - 0.001))
            if r1 >= repMax {
                if set2Consolidated && set3Consolidated {
                    if (w1 + step) <= maxW {
                        w1 += step
                        s1Adv = true
                    } else {
                        s1HeldReason = "Machine stack maximum reached (\(maxW) \(unit))"
                    }
                } else {
                    if !set2Consolidated {
                        s1HeldReason = "Set 2 (\(w2)) must reach ≥ 85% of Set 1 (\(roundToStep(w1 * 0.85, step: step)) \(unit))"
                    } else {
                        s1HeldReason = "Set 3 (\(w3)) must reach ≥ 65% of Set 1 (\(roundToStep(w1 * 0.65, step: step)) \(unit))"
                    }
                }
            }
            w1 = min(maxW, max(minW, w1))
            w2 = min(maxW, max(minW, max(w2, roundToStep(w1 * 0.80, step: step))))
            w3 = min(maxW, max(minW, max(w3, roundToStep(w1 * 0.60, step: step))))
        } else {
            if r2 >= repMax {
                if (w2 + step) <= min(maxW, w1) {
                    w2 += step
                    s2Adv = true
                }
            }
            let set2Consolidated = (w2 >= (w1 * 0.85 - 0.001))
            if r1 >= repMax {
                if set2Consolidated {
                    if (w1 + step) <= maxW {
                        w1 += step
                        s1Adv = true
                    } else {
                        s1HeldReason = "Machine stack maximum reached (\(maxW) \(unit))"
                    }
                } else {
                    s1HeldReason = "Set 2 (\(w2)) must reach ≥ 85% of Set 1 (\(roundToStep(w1 * 0.85, step: step)) \(unit))"
                }
            }
            w1 = min(maxW, max(minW, w1))
            w2 = min(maxW, max(minW, max(w2, roundToStep(w1 * 0.80, step: step))))
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
        consecutiveFailures: Int = 0,
        isAssisted: Bool = false,
        minWeight: Double? = nil,
        maxWeight: Double? = nil,
        unit: String = "lbs"
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
        let isKg = unit.lowercased() == "kg"
        let minW = minWeight ?? (isAssisted ? (isKg ? 2.5 : 5.0) : 0.0)
        let maxW = maxWeight ?? (isAssisted ? (isKg ? 50.0 : 100.0) : Double.infinity)

        if isAssisted {
            // SPEC-001 §11.2: Assisted Mode Missed Reps (R < R_min)
            // Athlete failed target reps -> Machine must provide MORE counterweight assistance (+S), bounded by machine ceiling (maxW)
            if r1 < repMin {
                if w1 >= maxW {
                    return MissedRepsOutcome(
                        loads: [maxW, max(maxW, w2), max(maxW, w3)],
                        activeSetsCount: activeSetsCount,
                        consecutiveFailures: consecutiveFailures,
                        extraSeconds: 60,
                        summary: "Anchor Set 1 missed (< \(repMin)r) at machine highest assistance limit (\(maxW) \(unit)). Machine ceiling reached; +60s compensatory rest awarded."
                    )
                }
                w1 = min(maxW, w1 + s)
                w2 = min(maxW, max(w1, w2))
                w3 = min(maxW, max(w2, w3))
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: activeSetsCount,
                    consecutiveFailures: consecutiveFailures,
                    extraSeconds: 60,
                    summary: "Anchor Set 1 missed (< \(repMin)r). Increased counterweight assistance to \(w1) \(unit) to preserve volume."
                )
            }

            if r2 < repMin {
                if w2 >= maxW {
                    return MissedRepsOutcome(
                        loads: [w1, maxW, max(maxW, w3)],
                        activeSetsCount: activeSetsCount,
                        consecutiveFailures: consecutiveFailures,
                        extraSeconds: 45,
                        summary: "Intermediate Set 2 missed (< \(repMin)r) at machine assistance ceiling (\(maxW) \(unit)). Assistance held; +45s rest awarded."
                    )
                }
                w2 = min(maxW, w2 + s)
                w3 = min(maxW, max(w2, w3))
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: activeSetsCount,
                    consecutiveFailures: consecutiveFailures,
                    extraSeconds: 0,
                    summary: "Intermediate Set 2 missed (< \(repMin)r). Increased counterweight assistance to \(w2) \(unit)."
                )
            }

            if activeSetsCount == 3 && r3 < repMin {
                if w3 >= maxW {
                    if consecutiveFailures >= 1 {
                        return MissedRepsOutcome(
                            loads: [w1, w2, maxW],
                            activeSetsCount: 2,
                            consecutiveFailures: 0,
                            extraSeconds: 0,
                            summary: "Consecutive assistance ceiling breach! Auto-transitioned to 2-Set Mode to recover capacity."
                        )
                    } else {
                        return MissedRepsOutcome(
                            loads: [w1, w2, maxW],
                            activeSetsCount: 3,
                            consecutiveFailures: 1,
                            extraSeconds: 60,
                            summary: "Set 3 hit machine assistance ceiling (\(maxW) \(unit)). Warning logged; +60s compensatory rest awarded."
                        )
                    }
                }
                w3 = min(maxW, w3 + s)
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: 3,
                    consecutiveFailures: 0,
                    extraSeconds: 0,
                    summary: "Base Set 3 missed (< \(repMin)r). Increased counterweight assistance to \(w3) \(unit)."
                )
            }

            return MissedRepsOutcome(
                loads: [w1, w2, w3],
                activeSetsCount: activeSetsCount,
                consecutiveFailures: consecutiveFailures,
                extraSeconds: 0,
                summary: "All sets within target rep window."
            )
        }

        // Standard Mode Missed Reps
        // Branch 1: Set 1 Failed
        if r1 < repMin {
            w1 = max(minW, w1 - s)
            let floor2 = max(minW, roundToStep(w1 * 0.80, step: s))
            let floor3 = max(minW, roundToStep(w1 * 0.60, step: s))
            w2 = max(floor2, min(w1, w2))
            w3 = max(floor3, min(w2, w3))
            return MissedRepsOutcome(
                loads: [w1, w2, w3],
                activeSetsCount: activeSetsCount,
                consecutiveFailures: consecutiveFailures,
                extraSeconds: 60,
                summary: "Set 1 missed threshold (< \(repMin)r). Anchor load deloaded by -\(s)\(w1 <= minW && minW > 0 ? " (Minimum stack plate reached)" : "")."
            )
        }

        // Branch 2: Set 2 Failed
        if r2 < repMin {
            let floor2 = max(minW, roundToStep(w1 * 0.80, step: s))
            let floor3 = max(minW, roundToStep(w1 * 0.60, step: s))
            if (w2 - s) >= floor2 && (w2 - s) >= minW {
                w2 -= s
                w3 = max(floor3, min(w2, w3))
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: activeSetsCount,
                    consecutiveFailures: consecutiveFailures,
                    extraSeconds: 0,
                    summary: "Set 2 missed threshold (< \(repMin)r). Intermediate load dropped by -\(s)."
                )
            } else {
                w2 = max(minW, floor2)
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: activeSetsCount,
                    consecutiveFailures: consecutiveFailures,
                    extraSeconds: 60,
                    summary: "Set 2 reached floor boundary (\(w2) \(unit)). Load held, +60s rest added."
                )
            }
        }

        // Branch 3: Set 3 Failed (3-set mode)
        if activeSetsCount == 3 && r3 < repMin {
            let floor3 = max(minW, roundToStep(w1 * 0.60, step: s))
            if (w3 - s) >= floor3 && (w3 - s) >= minW {
                w3 -= s
                return MissedRepsOutcome(
                    loads: [w1, w2, w3],
                    activeSetsCount: 3,
                    consecutiveFailures: 0,
                    extraSeconds: 0,
                    summary: "Set 3 missed threshold. Base load dropped by -\(s)."
                )
            } else {
                w3 = max(minW, floor3)
                // 60% floor breach event
                if consecutiveFailures >= 1 {
                    return MissedRepsOutcome(
                        loads: [w1, w2, w3],
                        activeSetsCount: 2,
                        consecutiveFailures: 0,
                        extraSeconds: 0,
                        summary: "Consecutive floor/stack breach! Dropped to 2-Set Mode to recover capacity."
                    )
                } else {
                    return MissedRepsOutcome(
                        loads: [w1, w2, w3],
                        activeSetsCount: 3,
                        consecutiveFailures: 1,
                        extraSeconds: 60,
                        summary: "Set 3 hit floor boundary (\(w3) \(unit)). Consecutive failure warning logged, +60s rest added."
                    )
                }
            }
        }

        return MissedRepsOutcome(
            loads: [w1, w2, w3],
            activeSetsCount: activeSetsCount,
            consecutiveFailures: consecutiveFailures,
            extraSeconds: 0,
            summary: "Loads maintained."
        )
    }

    // MARK: - Set 3 Re-Entry Gate (SPEC-001 §5.5)

    public struct Set3ReentryResult: Codable, Hashable {
        public var canReEnable: Bool
        public var initialW3: Double
        public var reason: String

        public init(canReEnable: Bool, initialW3: Double, reason: String) {
            self.canReEnable = canReEnable
            self.initialW3 = initialW3
            self.reason = reason
        }
    }

    public struct SessionPerformanceHistory {
        public var set1Load: Double
        public var set1Reps: Int
        public var set2Load: Double
        public var set2Reps: Int

        public init(set1Load: Double, set1Reps: Int, set2Load: Double, set2Reps: Int) {
            self.set1Load = set1Load
            self.set1Reps = set1Reps
            self.set2Load = set2Load
            self.set2Reps = set2Reps
        }
    }

    public static func evaluateSet3Reentry(
        currentW1: Double,
        microIncrement: Double,
        repWindowMax: Int,
        lastTwoSessions: [SessionPerformanceHistory]
    ) -> Set3ReentryResult {
        guard lastTwoSessions.count >= 2 else {
            return Set3ReentryResult(canReEnable: false, initialW3: 0.0, reason: "Requires at least 2 sessions in 2-set mode")
        }

        let s = microIncrement > 0 ? microIncrement : 2.5

        for (idx, session) in lastTwoSessions.prefix(2).enumerated() {
            // Gate 1: Set 2 load ratio >= 85% of Set 1
            if session.set2Load < (session.set1Load * 0.85 - 0.001) {
                return Set3ReentryResult(canReEnable: false, initialW3: 0.0, reason: "Session \(idx + 1) Set 2 load ratio < 85% of Set 1")
            }
            // Gate 2: Intersession fatigue drop <= 2 reps
            if (session.set1Reps - session.set2Reps) > 2 {
                return Set3ReentryResult(canReEnable: false, initialW3: 0.0, reason: "Session \(idx + 1) fatigue drop > 2 reps (\(session.set1Reps)r -> \(session.set2Reps)r)")
            }
            // Gate 3: Set 2 cleared rep ceiling
            if session.set2Reps < repWindowMax {
                return Set3ReentryResult(canReEnable: false, initialW3: 0.0, reason: "Session \(idx + 1) Set 2 did not clear rep ceiling (\(session.set2Reps) < \(repWindowMax))")
            }
        }

        // Re-enter at soft-entry 65% anchor load
        let softEntryW3 = roundToStep(currentW1 * 0.65, step: s)
        return Set3ReentryResult(
            canReEnable: true,
            initialW3: softEntryW3,
            reason: "All 3 gates passed for last 2 sessions! Set 3 re-enabled at 65% load (\(softEntryW3))."
        )
    }

    // MARK: - Periodic Recalibration (SPEC-001 §5.6)

    public enum RecalibrationStatus: String, Codable {
        case supercompensation = "SUPERCOMPENSATION"
        case fatigueFlag = "FATIGUE_FLAG"
        case verified = "VERIFIED"
    }

    public struct RecalibrationOutcome: Codable, Hashable {
        public var e1RM: Double
        public var status: RecalibrationStatus
        public var delta: Int
        public var summary: String

        public init(e1RM: Double, status: RecalibrationStatus, delta: Int, summary: String) {
            self.e1RM = e1RM
            self.status = status
            self.delta = delta
            self.summary = summary
        }
    }

    public static func evaluateRecalibration(
        currentE1RM: Double,
        testLoad: Double,
        actualReps: Int
    ) -> RecalibrationOutcome {
        guard testLoad > 0 else {
            return RecalibrationOutcome(e1RM: currentE1RM, status: .verified, delta: 0, summary: "Invalid test load")
        }

        let predictedReps = Int((30.0 * ((currentE1RM / testLoad) - 1.0)).rounded())
        let delta = actualReps - predictedReps
        let newE1RM = (testLoad * (1.0 + (Double(actualReps) / 30.0)) * 100.0).rounded() / 100.0

        if delta >= 2 {
            return RecalibrationOutcome(
                e1RM: newE1RM,
                status: .supercompensation,
                delta: delta,
                summary: "Supercompensation (+2+ reps)! e1RM upgraded to \(newE1RM)."
            )
        } else if delta <= -2 {
            return RecalibrationOutcome(
                e1RM: currentE1RM,
                status: .fatigueFlag,
                delta: delta,
                summary: "Fatigue Flag (≤ -2 reps under predicted). Capacity held for recovery."
            )
        } else {
            return RecalibrationOutcome(
                e1RM: newE1RM,
                status: .verified,
                delta: delta,
                summary: "Capacity Verified. e1RM updated to \(newE1RM)."
            )
        }
    }
}
