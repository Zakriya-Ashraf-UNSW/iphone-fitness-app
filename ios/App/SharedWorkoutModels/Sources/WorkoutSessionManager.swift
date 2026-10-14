import Foundation
import SwiftUI
import Combine

@MainActor
public final class WorkoutSessionManager: ObservableObject {
    public static let shared = WorkoutSessionManager()

    @Published public var currentSplit: WorkoutSplit = .push
    @Published public var exercises: [Exercise] = []
    @Published public var activeExerciseIndex: Int = 0
    @Published public var isRoutineActive: Bool = false
    @Published public var isMuted: Bool = false
    @Published public var selectedTab: Int = 0
    @Published public var showCustomRepsSheet: Bool = false

    // Chamber State
    @Published public var activeSetIndex: Int = 1
    @Published public var isTriageMode: Bool = false
    @Published public var isWarmupMode: Bool = false
    @Published public var warmupIndex: Int = 1
    @Published public var totalWarmups: Int = 0
    @Published public var warmupPrescription: WarmupPrescription? = nil
    @Published public var warmupsSkippedForExercise: [String: Bool] = [:]

    // Rest Timer
    @Published public var restTimerRunning: Bool = false
    @Published public var restTimerPrescribed: Int = 90
    @Published public var restTimerRemaining: Int = 90
    @Published public var restTimerLabel: String = "REST TIMER"
    @Published public var restTimerReason: String = ""
    private var restEndTime: Date? = nil
    private var timerCancellable: AnyCancellable? = nil

    // Set Verdicts & Triage
    @Published public var s1Outcome: String? = nil
    @Published public var s2Outcome: String? = nil
    @Published public var s3Outcome: String? = nil
    @Published public var s1Verdict: String? = nil
    @Published public var s2Verdict: String? = nil
    @Published public var s3Verdict: String? = nil
    @Published public var loggedReps: [Int] = [0, 0, 0]

    // Recap & Transition
    @Published public var isRecapShowing: Bool = false
    @Published public var recapOutcome: ProgressionOutcome? = nil
    @Published public var isTransitionRestMode: Bool = false
    @Published public var transitionRestRemaining: Int = 120
    @Published public var transitionNextExName: String = ""
    @Published public var isEndWorkoutSummaryShowing: Bool = false
    @Published public var sessionCompletedExercises: [SessionExerciseSummary] = []
    @Published public var lastExerciseExtraRest: Int = 0

    public var currentExercise: Exercise? {
        let list = exercisesForCurrentSplit
        guard list.indices.contains(activeExerciseIndex) else { return list.first }
        return list[activeExerciseIndex]
    }

    public var exercisesForCurrentSplit: [Exercise] {
        exercises.filter { $0.split.uppercased() == currentSplit.rawValue.uppercased() }
    }

    private init() {
        self.exercises = WorkoutStore.shared.loadExercises()
        startHeartbeatTimer()
        syncLiveActivity()
    }

    public func reloadData() {
        self.exercises = WorkoutStore.shared.loadExercises()
    }

    // MARK: - Exercise Management

    public func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
        WorkoutStore.shared.saveExercises(exercises)
        Theme.hapticNotification(.success)
    }

    public func updateExercise(_ exercise: Exercise) {
        if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[idx] = exercise
            WorkoutStore.shared.saveExercises(exercises)
            Theme.hapticNotification(.success)
        }
    }

    public func deleteExercise(id: String) {
        exercises.removeAll(where: { $0.id == id })
        WorkoutStore.shared.saveExercises(exercises)
        if activeExerciseIndex >= exercisesForCurrentSplit.count {
            activeExerciseIndex = max(0, exercisesForCurrentSplit.count - 1)
        }
        Theme.hapticNotification(.warning)
    }

    public func applyCalibration(
        exerciseId: String,
        e1RM: Double,
        fatigueIndex: Double,
        loads: [Double],
        set1Load: Double? = nil,
        set1Reps: Int? = nil,
        set2Load: Double? = nil,
        set2Reps: Int? = nil
    ) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        var ex = exercises[idx]
        ex.isCalibrated = true
        ex.e1RM = e1RM
        ex.fatigueIndex = fatigueIndex
        ex.loads = loads
        ex.weight = loads.first ?? ex.weight
        ex.sessionsSinceRecalibration = 0
        exercises[idx] = ex
        WorkoutStore.shared.saveExercises(exercises)

        let s1Load = set1Load ?? (loads.first ?? ex.weight)
        let s1R = set1Reps ?? ex.repWindowMax
        let s2Load = set2Load ?? (ex.isAssisted ? s1Load * 1.20 : s1Load * 0.80)
        let s2R = set2Reps ?? max(1, ex.repWindowMin)
        let fiPct = Int(round(fatigueIndex * 100))
        let summary = "2-Set Calibration Complete: e1RM \(String(format: "%.1f", e1RM)) \(ex.unit.uppercased()) • Fatigue Index \(fiPct)%. Baseline: \(String(format: "%.1f", s1Load)) x \(s1R)r -> Drop: \(String(format: "%.1f", s2Load)) x \(s2R)r. Prescribed: \(loads.map { String(format: "%.1f", $0) }.joined(separator: " / ")) \(ex.unit.uppercased())."

        let calibrationEntry = WorkoutHistoryEntry(
            exerciseId: ex.id,
            exerciseName: ex.name,
            split: ex.split,
            unit: ex.unit,
            targetSets: 2,
            loadsUsed: [s1Load, s2Load, 0.0],
            nextLoads: loads,
            weightUsed: s1Load,
            nextTargetWeight: loads.first ?? ex.weight,
            increment: ex.microIncrement,
            set1Reps: "\(s1R)",
            set2Reps: "\(s2R)",
            set3Reps: "—",
            fatigueIndex: fatigueIndex,
            e1RM: e1RM,
            progressionSummary: summary,
            isAssisted: ex.isAssisted,
            isCalibration: true,
            entryType: "CALIBRATION"
        )
        WorkoutStore.shared.appendHistoryEntry(calibrationEntry)

        Theme.hapticNotification(.success)
        AudioManager.shared.playFanfare()
    }

    public func resetExerciseCalibration(id: String) {
        guard let idx = exercises.firstIndex(where: { $0.id == id }) else { return }
        var ex = exercises[idx]
        ex.isCalibrated = false
        ex.e1RM = 0.0
        ex.fatigueIndex = 0.0
        ex.sessionsSinceRecalibration = 0
        exercises[idx] = ex
        WorkoutStore.shared.saveExercises(exercises)
        Theme.hapticNotification(.warning)
    }

    public func resetAllCalibration() {
        for i in exercises.indices {
            exercises[i].isCalibrated = false
            exercises[i].e1RM = 0.0
            exercises[i].fatigueIndex = 0.0
            exercises[i].sessionsSinceRecalibration = 0
        }
        WorkoutStore.shared.saveExercises(exercises)
        Theme.hapticNotification(.warning)
    }

    public func restoreDefaults() {
        self.exercises = WorkoutStore.shared.restoreDefaultExercises()
        self.activeExerciseIndex = 0
        Theme.hapticNotification(.success)
    }

    public func toggleMute() {
        isMuted.toggle()
        AudioManager.shared.isMuted = isMuted
        Theme.hapticImpact(.light)
    }

    // MARK: - Routine & Exercise Control

    public func startRoutine(split: WorkoutSplit, at index: Int = 0) {
        self.currentSplit = split
        self.activeExerciseIndex = index
        self.isRoutineActive = true
        self.activeSetIndex = 1
        self.isRecapShowing = false
        self.isTransitionRestMode = false
        self.isEndWorkoutSummaryShowing = false
        self.sessionCompletedExercises = []
        Theme.hapticNotification(.success)
        initCurrentExercise()
    }

    public func startLift(exerciseId: String) {
        if let ex = exercises.first(where: { $0.id == exerciseId }),
           let split = WorkoutSplit(rawValue: ex.split.uppercased()) {
            self.currentSplit = split
            let splitList = exercisesForCurrentSplit
            if let idx = splitList.firstIndex(where: { $0.id == exerciseId }) {
                self.activeExerciseIndex = idx
            }
        }
        self.isRoutineActive = true
        self.activeSetIndex = 1
        self.isTriageMode = false
        self.isRecapShowing = false
        self.isTransitionRestMode = false
        self.isEndWorkoutSummaryShowing = false
        self.sessionCompletedExercises = []
        Theme.hapticNotification(.success)
        initCurrentExercise()
    }

    public func initCurrentExercise() {
        guard let ex = currentExercise else { return }
        self.s1Outcome = nil
        self.s2Outcome = nil
        self.s3Outcome = nil
        self.s1Verdict = nil
        self.s2Verdict = nil
        self.s3Verdict = nil
        self.loggedReps = [0, 0, 0]
        self.activeSetIndex = 1
        self.isTriageMode = false
        self.lastExerciseExtraRest = 0
        self.stopRestTimer()

        // Check warmups
        let workedMuscles = getPreviousMuscleGroupsWorked()
        let prescription = WarmupCalculator.generateWarmupPrescription(exercise: ex, previousMuscleGroupsWorked: workedMuscles)
        self.warmupPrescription = prescription

        if !prescription.warmups.isEmpty && warmupsSkippedForExercise[ex.id] != true {
            self.isWarmupMode = true
            self.totalWarmups = prescription.warmups.count
            self.warmupIndex = 1
            let w = prescription.warmups[0]
            self.restTimerPrescribed = w.restSeconds
            self.restTimerRemaining = w.restSeconds
            self.restTimerLabel = "REST AFTER WARM-UP 1"
            self.restTimerReason = "\(w.restSeconds)s Warm-up Recovery"
        } else {
            self.isWarmupMode = false
            self.totalWarmups = 0
            preparePrescribedRestUI(forSet: 2, autoStart: false)
        }
        syncLiveActivity()
    }

    private func getPreviousMuscleGroupsWorked() -> [String] {
        let list = exercisesForCurrentSplit
        var groups: [String] = []
        for i in 0..<min(activeExerciseIndex, list.count) {
            let m = list[i].muscleGroup.uppercased()
            if !groups.contains(m) { groups.append(m) }
        }
        return groups
    }

    // MARK: - Warmup Progression

    public func completeWarmupSet() {
        guard isWarmupMode, let prescription = warmupPrescription, prescription.warmups.indices.contains(warmupIndex - 1) else { return }
        Theme.hapticImpact(.medium)
        let w = prescription.warmups[warmupIndex - 1]
        let restSec = w.restSeconds
        let nextLabel = (warmupIndex < totalWarmups) ? "REST FOR WARM-UP \(warmupIndex + 1)" : "REST FOR SET 1 (ANCHOR SET)"
        startRestTimer(seconds: restSec, label: nextLabel, reason: "\(restSec)s Warm-up Recovery")
        syncLiveActivity()
    }

    public func advanceWarmup() {
        guard isWarmupMode else { return }
        stopRestTimer()
        Theme.hapticImpact(.light)
        if warmupIndex < totalWarmups {
            warmupIndex += 1
            if let prescription = warmupPrescription, prescription.warmups.indices.contains(warmupIndex - 1) {
                let w = prescription.warmups[warmupIndex - 1]
                self.restTimerPrescribed = w.restSeconds
                self.restTimerRemaining = w.restSeconds
                self.restTimerLabel = "REST AFTER WARM-UP \(warmupIndex)"
                self.restTimerReason = "\(w.restSeconds)s Warm-up Recovery"
            }
        } else {
            isWarmupMode = false
            preparePrescribedRestUI(forSet: 2, autoStart: false)
        }
        syncLiveActivity()
    }

    public func skipWarmups() {
        guard let ex = currentExercise else { return }
        stopRestTimer()
        warmupsSkippedForExercise[ex.id] = true
        isWarmupMode = false
        Theme.hapticImpact(.light)
        preparePrescribedRestUI(forSet: 2, autoStart: false)
        syncLiveActivity()
    }

    // MARK: - Working Set Triage & Advancements

    public func updateCurrentExerciseSetLoad(setIndex: Int, load: Double) {
        guard let ex = currentExercise, let idx = exercises.firstIndex(where: { $0.id == ex.id }) else { return }
        var updated = ex
        while updated.loads.count <= setIndex {
            updated.loads.append(updated.weight)
        }
        updated.loads[setIndex] = load
        if setIndex == 0 {
            updated.weight = load
        }
        exercises[idx] = updated
        WorkoutStore.shared.saveExercises(exercises)
        syncLiveActivity()
    }

    public func logSet1(outcome: String, customReps: Int? = nil, customLoad: Double? = nil) {
        guard let ex = currentExercise else { return }
        if let l = customLoad {
            updateCurrentExerciseSetLoad(setIndex: 0, load: l)
        }
        self.isTriageMode = false
        self.s1Outcome = outcome
        Theme.hapticImpact(.medium)

        let targetReps = ex.repWindowMax
        let repsLogged: Int
        if let custom = customReps {
            repsLogged = custom
        } else {
            switch outcome {
            case "overload":
                repsLogged = targetReps + 1
            case "target":
                repsLogged = (ex.repWindowMax > ex.repWindowMin)
                    ? (ex.repWindowMin + ex.repWindowMax) / 2
                    : ex.repWindowMax
            default:
                repsLogged = max(0, ex.repWindowMin - 1)
            }
        }

        switch outcome {
        case "overload":
            s1Verdict = "Verdict: Hypertrophy overload confirmed! Anchor load primed for promotion."
        case "target":
            s1Verdict = "Verdict: Target window satisfied (\(ex.repWindowMin)–\(ex.repWindowMax) reps). Anchor load maintained."
        default:
            s1Verdict = "Verdict: Set 1 under threshold (< \(ex.repWindowMin) reps). Maintain anchor load & extend rest."
        }
        loggedReps[0] = repsLogged

        let s1Missed = repsLogged < ex.repWindowMin
        let extra = s1Missed ? 60 : 0
        preparePrescribedRestUI(forSet: 2, autoStart: true, extraSeconds: extra)
        syncLiveActivity()
    }

    public func goToSet(_ setNum: Int) {
        guard (1...3).contains(setNum) else { return }
        Theme.hapticImpact(.light)
        self.activeSetIndex = setNum
        if !restTimerRunning {
            preparePrescribedRestUI(forSet: min(currentExercise?.activeSetsCount ?? 3, setNum + 1), autoStart: false)
        }
        syncLiveActivity()
    }

    public func logSet2(outcome: String, customReps: Int? = nil, customLoad: Double? = nil) {
        guard let ex = currentExercise else { return }
        if let l = customLoad {
            updateCurrentExerciseSetLoad(setIndex: 1, load: l)
        }
        self.isTriageMode = false
        self.s2Outcome = outcome
        Theme.hapticImpact(.medium)

        let targetReps = ex.repWindowMax
        let repsLogged: Int
        if let custom = customReps {
            repsLogged = custom
        } else {
            switch outcome {
            case "overload":
                repsLogged = targetReps + 1
            case "target":
                repsLogged = (ex.repWindowMax > ex.repWindowMin)
                    ? (ex.repWindowMin + ex.repWindowMax) / 2
                    : ex.repWindowMax
            default:
                repsLogged = max(0, ex.repWindowMin - 1)
            }
        }

        switch outcome {
        case "overload":
            s2Verdict = "Verdict: Set 2 overload cleared. Intermediate foundation advancing."
        case "target":
            s2Verdict = "Verdict: Set 2 within target rep window."
        default:
            s2Verdict = "Verdict: Set 2 under threshold (< \(ex.repWindowMin) reps)."
        }
        loggedReps[1] = repsLogged

        if ex.activeSetsCount == 2 {
            completeExerciseAndEvaluateRecap()
        } else {
            let resolution = DPOEngine.resolveSet3Parameters(exercise: ex, pacingMode: "FAST_PACED")
            var s3RestSec = resolution.restTimerSeconds
            var reason = resolution.loadDroppedForFatigue ? (ex.isAssisted ? "Fatigue-Coupled +Pin Assist Added" : "Fatigue-Coupled 60% Floor Drop") : "Standard Prescribed Rest"

            if repsLogged < ex.repWindowMin {
                if ex.isAssisted {
                    let maxW = ex.effectiveMaxWeight
                    let s2Load = ex.loads.count > 1 ? ex.loads[1] : ex.loads[0]
                    if (s2Load + ex.microIncrement) > maxW {
                        s3RestSec += 45
                        reason = "Set 2 Machine Max Assistance Ceiling (+45s Compensatory Rest)"
                    } else {
                        reason = "Set 2 Under Threshold (Assistance Increased)"
                    }
                } else {
                    let floor2 = DPOEngine.roundToStep(ex.loads[0] * 0.80, step: ex.microIncrement)
                    let s2Load = ex.loads.count > 1 ? ex.loads[1] : ex.loads[0]
                    if (s2Load - ex.microIncrement) < floor2 {
                        s3RestSec += 60
                        reason = "Set 2 80% Floor Boundary (+60s Compensatory Rest)"
                    } else {
                        reason = "Set 2 Under Threshold (Load Dropped)"
                    }
                }
            }

            self.restTimerPrescribed = s3RestSec
            self.restTimerRemaining = s3RestSec
            self.restTimerLabel = "REST FOR SET 3 (BASE OVERLOAD)"
            self.restTimerReason = reason
            startRestTimer(seconds: s3RestSec, label: restTimerLabel, reason: restTimerReason)
            syncLiveActivity()
        }
    }

    public func logSet3(outcome: String, customReps: Int? = nil, customLoad: Double? = nil) {
        guard let ex = currentExercise else { return }
        if let l = customLoad {
            updateCurrentExerciseSetLoad(setIndex: 2, load: l)
        }
        self.isTriageMode = false
        self.s3Outcome = outcome
        Theme.hapticImpact(.medium)

        let targetReps = ex.repWindowMax
        let repsLogged: Int
        if let custom = customReps {
            repsLogged = custom
        } else {
            switch outcome {
            case "overload":
                repsLogged = targetReps + 1
            case "target":
                repsLogged = (ex.repWindowMax > ex.repWindowMin)
                    ? (ex.repWindowMin + ex.repWindowMax) / 2
                    : ex.repWindowMax
            default:
                repsLogged = max(0, ex.repWindowMin - 1)
            }
        }

        switch outcome {
        case "overload":
            s3Verdict = ex.isAssisted
                ? "Verdict: Base assistance volume cleared! Overload primed."
                : "Verdict: Bottom cascade overload satisfied! Next cycle primed."
        case "target":
            s3Verdict = "Verdict: Base set volume maintained."
        default:
            s3Verdict = "Verdict: Base set under threshold (< \(ex.repWindowMin) reps)."
        }
        loggedReps[2] = repsLogged

        completeExerciseAndEvaluateRecap()
    }

    // MARK: - Post-Exercise Recap & History Logging

    public func commitCurrentExercise() {
        completeExerciseAndEvaluateRecap()
    }

    public func completeExerciseAndEvaluateRecap() {
        guard var ex = currentExercise else { return }
        stopRestTimer()

        // Capture loads actually lifted in this session before mutating ex.loads
        let usedLoads: [Double] = (0..<ex.activeSetsCount).map { i in
            ex.loads.indices.contains(i) ? ex.loads[i] : (ex.loads.first ?? ex.weight)
        }

        var outcome: ProgressionOutcome
        let anyMissed = (loggedReps[0] < ex.repWindowMin) ||
                        (loggedReps[1] < ex.repWindowMin) ||
                        (ex.activeSetsCount == 3 && loggedReps[2] < ex.repWindowMin)

        if anyMissed {
            let missedResult = DPOEngine.handleMissedReps(
                loads: ex.loads,
                reps: loggedReps,
                activeSetsCount: ex.activeSetsCount,
                repMin: ex.repWindowMin,
                microIncrement: ex.microIncrement,
                consecutiveFailures: ex.consecutiveSet3Failures,
                isAssisted: ex.isAssisted,
                minWeight: ex.minWeight,
                maxWeight: ex.maxWeight,
                unit: ex.unit
            )
            ex.loads = missedResult.loads
            ex.weight = missedResult.loads.first ?? ex.weight
            ex.activeSetsCount = missedResult.activeSetsCount
            ex.consecutiveSet3Failures = missedResult.consecutiveFailures
            self.lastExerciseExtraRest = missedResult.extraSeconds
            outcome = ProgressionOutcome(
                loads: missedResult.loads,
                s1Adv: false,
                s2Adv: false,
                s3Adv: false,
                s1HeldReason: missedResult.summary,
                summary: missedResult.summary
            )
        } else {
            self.lastExerciseExtraRest = 0
            outcome = DPOEngine.evaluateProgression(
                loads: ex.loads,
                reps: loggedReps,
                activeSetsCount: ex.activeSetsCount,
                repMax: ex.repWindowMax,
                microIncrement: ex.microIncrement,
                unit: ex.unit,
                isAssisted: ex.isAssisted,
                minWeight: ex.minWeight,
                maxWeight: ex.maxWeight
            )

            // Gating: Only advance sets if their triage outcome was explicitly "overload"
            if s1Outcome != "overload" {
                outcome.s1Adv = false
                if outcome.loads.indices.contains(0) {
                    outcome.loads[0] = usedLoads[0]
                }
            }
            if s2Outcome != "overload" {
                outcome.s2Adv = false
                if outcome.loads.indices.contains(1) {
                    outcome.loads[1] = usedLoads.indices.contains(1) ? usedLoads[1] : outcome.loads[1]
                }
            }
            if s3Outcome != "overload" {
                outcome.s3Adv = false
                if outcome.loads.indices.contains(2) {
                    outcome.loads[2] = usedLoads.indices.contains(2) ? usedLoads[2] : outcome.loads[2]
                }
            }

            if !outcome.s1Adv && !outcome.s2Adv && !outcome.s3Adv {
                outcome.summary = "Working Load Consolidated (Target Window Satisfied)"
            }

            ex.loads = outcome.loads
            ex.weight = outcome.loads.first ?? ex.weight

            // SPEC-001 §5.5 Set 3 Re-Entry Gate evaluation for 2-set mode
            if ex.activeSetsCount == 2 {
                let currentSessionPerf = DPOEngine.SessionPerformanceHistory(
                    set1Load: usedLoads[0],
                    set1Reps: loggedReps[0],
                    set2Load: usedLoads.indices.contains(1) ? usedLoads[1] : (usedLoads[0] * 0.8),
                    set2Reps: loggedReps[1]
                )
                let priorHistory = WorkoutStore.shared.loadHistory().filter { $0.exerciseId == ex.id }
                if let lastEntry = priorHistory.last,
                   let prevR1 = Int(lastEntry.set1Reps),
                   let prevR2 = Int(lastEntry.set2Reps) {
                    let prevL1 = lastEntry.loadsUsed.indices.contains(0) ? lastEntry.loadsUsed[0] : lastEntry.weightUsed
                    let prevL2 = lastEntry.loadsUsed.indices.contains(1) ? lastEntry.loadsUsed[1] : (prevL1 * 0.8)
                    let prevSessionPerf = DPOEngine.SessionPerformanceHistory(
                        set1Load: prevL1,
                        set1Reps: prevR1,
                        set2Load: prevL2,
                        set2Reps: prevR2
                    )
                    let reentry = DPOEngine.evaluateSet3Reentry(
                        currentW1: ex.loads[0],
                        microIncrement: ex.microIncrement,
                        repWindowMax: ex.repWindowMax,
                        lastTwoSessions: [prevSessionPerf, currentSessionPerf]
                    )
                    if reentry.canReEnable {
                        ex.activeSetsCount = 3
                        if ex.loads.count >= 3 {
                            ex.loads[2] = reentry.initialW3
                        } else {
                            ex.loads.append(reentry.initialW3)
                        }
                        outcome.loads = ex.loads
                        outcome.summary += " • \(reentry.reason)"
                    }
                }
            }
        }

        self.recapOutcome = outcome
        ex.sessionsSinceRecalibration += 1
        ex.e1RM = DPOEngine.calculateE1RM(load: ex.weight, reps: Double(loggedReps[0]))
        if let idx = exercises.firstIndex(where: { $0.id == ex.id }) {
            exercises[idx] = ex
            WorkoutStore.shared.saveExercises(exercises)
        }

        // Calculate load deltas for all sets
        let nextLoadsTarget = outcome.loads
        var deltas: [Double] = []
        for i in 0..<ex.activeSetsCount {
            let used = usedLoads.indices.contains(i) ? usedLoads[i] : 0
            let next = nextLoadsTarget.indices.contains(i) ? nextLoadsTarget[i] : used
            deltas.append(((next - used) * 100).rounded() / 100)
        }

        let exerciseSummary = SessionExerciseSummary(
            exerciseId: ex.id,
            exerciseName: ex.name,
            muscleGroup: ex.muscleGroup,
            split: ex.split,
            unit: ex.unit,
            targetSets: ex.activeSetsCount,
            loggedReps: Array(loggedReps.prefix(ex.activeSetsCount)),
            loadsUsed: usedLoads,
            nextLoads: nextLoadsTarget,
            deltas: deltas,
            progressionSummary: outcome.summary,
            isAnchorPromoted: outcome.s1Adv,
            isAssisted: ex.isAssisted
        )

        // Store into current session list (update if already exists or append)
        if let existingIdx = sessionCompletedExercises.firstIndex(where: { $0.exerciseId == ex.id }) {
            sessionCompletedExercises[existingIdx] = exerciseSummary
        } else {
            sessionCompletedExercises.append(exerciseSummary)
        }

        let historyEntry = WorkoutHistoryEntry(
            exerciseId: ex.id,
            exerciseName: ex.name,
            split: ex.split,
            unit: ex.unit,
            targetSets: ex.activeSetsCount,
            loadsUsed: [usedLoads[0], usedLoads.indices.contains(1) ? usedLoads[1] : 0, usedLoads.indices.contains(2) ? usedLoads[2] : 0],
            nextLoads: outcome.loads,
            weightUsed: usedLoads.first ?? ex.weight,
            nextTargetWeight: outcome.loads.first ?? ex.weight,
            increment: ex.microIncrement,
            set1Reps: "\(loggedReps[0])",
            set2Reps: "\(loggedReps[1])",
            set3Reps: "\(loggedReps[2])",
            fatigueIndex: ex.fatigueIndex,
            e1RM: ex.e1RM,
            progressionSummary: outcome.summary,
            isAssisted: ex.isAssisted
        )
        WorkoutStore.shared.appendHistoryEntry(historyEntry)

        self.isRecapShowing = true
        if outcome.s1Adv {
            AudioManager.shared.playFanfare()
        }
        syncLiveActivity()
    }

    public var isLastExerciseInCurrentRoutine: Bool {
        activeExerciseIndex >= max(0, exercisesForCurrentSplit.count - 1)
    }

    public func advanceToNextExerciseAfterRecap() {
        self.isRecapShowing = false
        let list = exercisesForCurrentSplit
        let nextIndex = activeExerciseIndex + 1

        if nextIndex < list.count {
            self.isTransitionRestMode = true
            let baseTransition = 120
            let totalTransition = baseTransition + lastExerciseExtraRest
            self.transitionRestRemaining = totalTransition
            self.transitionNextExName = list[nextIndex].name
            let reason = lastExerciseExtraRest > 0 ? "120s Transition + \(lastExerciseExtraRest)s Compensatory Rest" : "Inter-Exercise Recovery"
            startRestTimer(seconds: totalTransition, label: "TRANSITION TO \(list[nextIndex].name.uppercased())", reason: reason)
            syncLiveActivity()
        } else {
            finishWorkoutAndShowSummary()
        }
    }

    public func finishWorkoutAndShowSummary() {
        self.isRecapShowing = false
        self.isTransitionRestMode = false
        self.stopRestTimer()
        self.isEndWorkoutSummaryShowing = true
        Theme.hapticNotification(.success)
        AudioManager.shared.playFanfare()
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.endActivity()
        }
    }

    public func dismissEndWorkoutSummary() {
        self.isRoutineActive = false
        self.isEndWorkoutSummaryShowing = false
        self.isRecapShowing = false
        self.isTransitionRestMode = false
        self.activeExerciseIndex = 0
        self.activeSetIndex = 1
        self.stopRestTimer()
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.endActivity()
        }
    }

    public func skipTransitionRest() {
        stopRestTimer()
        self.isTransitionRestMode = false
        let list = exercisesForCurrentSplit
        let nextIndex = activeExerciseIndex + 1
        if nextIndex < list.count {
            self.activeExerciseIndex = nextIndex
            initCurrentExercise()
        }
    }

    // MARK: - Rest Timer & Heartbeat

    private func preparePrescribedRestUI(forSet targetSet: Int, autoStart: Bool, extraSeconds: Int = 0) {
        guard let ex = currentExercise else { return }
        let limits = DPOEngine.restLimits[ex.category] ?? RestLimit(min: 75, defaultSec: 90, max: 120)
        let baseRestSec = (targetSet == 2) ? limits.defaultSeconds : limits.minSeconds
        let totalRestSec = baseRestSec + extraSeconds
        self.restTimerPrescribed = totalRestSec
        self.restTimerRemaining = totalRestSec
        self.restTimerLabel = "REST FOR SET \(targetSet)"
        self.restTimerReason = extraSeconds > 0 ? "\(baseRestSec)s Prescribed + \(extraSeconds)s Compensatory Rest" : "\(totalRestSec)s Prescribed Rest"

        if autoStart {
            startRestTimer(seconds: totalRestSec, label: restTimerLabel, reason: restTimerReason)
        } else {
            stopRestTimer()
        }
    }

    public func startRestTimer(seconds: Int, label: String, reason: String = "") {
        self.restTimerPrescribed = seconds
        self.restTimerRemaining = seconds
        self.restTimerLabel = label
        self.restTimerReason = reason
        self.restEndTime = Date().addingTimeInterval(Double(seconds))
        self.restTimerRunning = true
        Theme.hapticImpact(.medium)
        syncLiveActivity()
    }

    public func completeCurrentRestAndAdvance() {
        guard restTimerRunning else {
            self.restEndTime = nil
            return
        }
        self.restTimerRunning = false
        self.restEndTime = nil

        if isTransitionRestMode {
            skipTransitionRest()
        } else if isWarmupMode {
            advanceWarmup()
        } else {
            self.isTriageMode = false
            if restTimerLabel.contains("SET 2") && activeSetIndex == 1 {
                activeSetIndex = 2
            } else if restTimerLabel.contains("SET 3") && activeSetIndex == 2 {
                activeSetIndex = 3
            }
            syncLiveActivity()
        }
    }

    public func stopRestTimer() {
        completeCurrentRestAndAdvance()
    }

    public func adjustRest(by seconds: Int) {
        guard restTimerRunning, let end = restEndTime else { return }
        let newEnd = end.addingTimeInterval(Double(seconds))
        self.restEndTime = newEnd
        self.restTimerRemaining = max(0, Int(newEnd.timeIntervalSinceNow))
        Theme.hapticImpact(.light)
        syncLiveActivity()
    }

    private func startHeartbeatTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.onTimerTick()
            }
    }

    private func onTimerTick() {
        guard restTimerRunning, let end = restEndTime else { return }
        let remaining = Int(end.timeIntervalSinceNow)
        if remaining <= 0 {
            self.restTimerRemaining = 0
            self.restTimerRunning = false
            self.restEndTime = nil
            Theme.hapticSuccess()
            AudioManager.shared.playTimerComplete()
            completeCurrentRestAndAdvance()
        } else {
            self.restTimerRemaining = remaining
            // Countdown sensory feedback on last 5 seconds
            if remaining <= 5 {
                Theme.hapticTick()
                if remaining <= 3 {
                    AudioManager.shared.playCountdownTick()
                }
            }
        }
    }

    // MARK: - Live Activity Sync

    public func syncLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        guard let ex = currentExercise else { return }

        // If resting, determine the upcoming set being prepared for
        let displaySetIndex: Int
        if restTimerRunning && restTimerLabel.contains("SET 2") {
            displaySetIndex = 2
        } else if restTimerRunning && restTimerLabel.contains("SET 3") {
            displaySetIndex = 3
        } else {
            displaySetIndex = activeSetIndex
        }

        let loadIdx = max(0, min(displaySetIndex - 1, ex.loads.count - 1))
        let load = ex.loads.indices.contains(loadIdx) ? ex.loads[loadIdx] : ex.weight
        let loadText = ex.isAssisted
            ? String(format: "%.1f %@ Assist", load, ex.unit.uppercased())
            : String(format: "%.1f %@", load, ex.unit.uppercased())
        let targetRepsText = "\(ex.repWindowMin)–\(ex.repWindowMax) Reps"

        let nextLoadIdx = min(displaySetIndex, ex.loads.count - 1)
        let nextLoad = ex.loads.indices.contains(nextLoadIdx) ? ex.loads[nextLoadIdx] : load
        let nextSetLoadText = ex.isAssisted
            ? String(format: "%.1f %@ Assist", nextLoad, ex.unit.uppercased())
            : String(format: "%.1f %@", nextLoad, ex.unit.uppercased())

        let restEnd = restTimerRunning ? restEndTime?.timeIntervalSince1970 : nil

        let contentState = WorkoutActivityAttributes.ContentState(
            splitName: currentSplit.rawValue.uppercased(),
            exerciseName: ex.name,
            setIndex: displaySetIndex,
            totalSets: ex.activeSetsCount,
            loadText: loadText,
            targetRepsText: targetRepsText,
            isResting: restTimerRunning,
            restEndTimestamp: restEnd,
            isTriageLogging: isTriageMode && !restTimerRunning && !isRecapShowing && !isTransitionRestMode && !isWarmupMode,
            underTargetText: ex.isAssisted ? "< \(ex.repWindowMin) (More Help)" : "< \(ex.repWindowMin) Missed",
            prescribedTargetText: "\(ex.repWindowMin)–\(ex.repWindowMax) Target",
            overloadTargetText: "\(ex.repWindowMax + 1)+ Overload",
            overloadIncrementText: ex.isAssisted ? "-1 Pin Assist (-\(ex.microIncrement) \(ex.unit))" : "+\(ex.microIncrement) \(ex.unit)",
            isRecap: isRecapShowing,
            recapLoggedSetsText: "S1: \(loggedReps[0])r • S2: \(loggedReps[1])r • S3: \(loggedReps[2])r",
            recapProgressionHeadline: recapOutcome?.summary ?? "WORKING LOAD CONSOLIDATED",
            recapNextTargetText: "Next Anchor: \(recapOutcome?.loads.first ?? ex.weight) \(ex.unit)\(ex.isAssisted ? " Assist" : "")",
            recapIsFinalExercise: activeExerciseIndex >= exercisesForCurrentSplit.count - 1,
            isWarmup: isWarmupMode,
            warmupIndex: warmupIndex,
            totalWarmups: totalWarmups,
            warmupTargetText: warmupPrescription?.warmups.indices.contains(warmupIndex - 1) == true ? "\(warmupPrescription!.warmups[warmupIndex - 1].targetReps) reps @ \(warmupPrescription!.warmups[warmupIndex - 1].load) \(ex.unit)\(ex.isAssisted ? " Assist" : "")" : "",
            isTransitionRest: isTransitionRestMode,
            nextExerciseName: transitionNextExName,
            restTimerLabel: restTimerLabel,
            nextSetLoadText: nextSetLoadText
        )

        LiveActivityManager.shared.syncWorkoutState(contentState)
    }
}
