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

    // Chamber State
    @Published public var activeSetIndex: Int = 1
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

    public func applyCalibration(exerciseId: String, e1RM: Double, fatigueIndex: Double, loads: [Double]) {
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
        self.isRecapShowing = false
        self.isTransitionRestMode = false
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

    public func logSet1(outcome: String, customReps: Int? = nil) {
        guard let ex = currentExercise else { return }
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
                repsLogged = targetReps
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

        preparePrescribedRestUI(forSet: 2, autoStart: true)
        syncLiveActivity()
    }

    public func goToSet(_ setNum: Int) {
        guard (1...3).contains(setNum) else { return }
        Theme.hapticImpact(.light)
        self.activeSetIndex = setNum
        if !restTimerRunning {
            preparePrescribedRestUI(forSet: setNum + 1, autoStart: false)
        }
        syncLiveActivity()
    }

    public func logSet2(outcome: String, customReps: Int? = nil) {
        guard let ex = currentExercise else { return }
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
                repsLogged = targetReps
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
            let resolution = DPOEngine.resolveSet3Parameters(
                loads: ex.loads,
                category: ex.category,
                microIncrement: ex.microIncrement,
                fatigueIndex: ex.fatigueIndex,
                pacingMode: "FAST_PACED"
            )
            self.restTimerPrescribed = resolution.restTimerSeconds
            self.restTimerRemaining = resolution.restTimerSeconds
            self.restTimerLabel = "REST FOR SET 3 (BASE OVERLOAD)"
            self.restTimerReason = resolution.loadDroppedForFatigue ? "Fatigue-Coupled 60% Floor Drop" : "Standard Prescribed Rest"
            startRestTimer(seconds: resolution.restTimerSeconds, label: restTimerLabel, reason: restTimerReason)
            syncLiveActivity()
        }
    }

    public func logSet3(outcome: String, customReps: Int? = nil) {
        guard let ex = currentExercise else { return }
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
                repsLogged = targetReps
            default:
                repsLogged = max(0, ex.repWindowMin - 1)
            }
        }

        switch outcome {
        case "overload":
            s3Verdict = "Verdict: Bottom cascade overload satisfied! Next cycle primed."
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

        let outcome: ProgressionOutcome
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
                consecutiveFailures: ex.consecutiveSet3Failures
            )
            ex.loads = missedResult.loads
            ex.weight = missedResult.loads.first ?? ex.weight
            ex.activeSetsCount = missedResult.activeSetsCount
            ex.consecutiveSet3Failures = missedResult.consecutiveFailures
            outcome = ProgressionOutcome(
                loads: missedResult.loads,
                s1Adv: false,
                s2Adv: false,
                s3Adv: false,
                s1HeldReason: missedResult.summary,
                summary: missedResult.summary
            )
        } else {
            outcome = DPOEngine.evaluateProgression(
                loads: ex.loads,
                reps: loggedReps,
                activeSetsCount: ex.activeSetsCount,
                repMax: ex.repWindowMax,
                microIncrement: ex.microIncrement
            )
            ex.loads = outcome.loads
            ex.weight = outcome.loads.first ?? ex.weight
        }

        self.recapOutcome = outcome
        ex.sessionsSinceRecalibration += 1
        ex.e1RM = DPOEngine.calculateE1RM(load: ex.weight, reps: Double(loggedReps[0]))
        if let idx = exercises.firstIndex(where: { $0.id == ex.id }) {
            exercises[idx] = ex
            WorkoutStore.shared.saveExercises(exercises)
        }

        let historyEntry = WorkoutHistoryEntry(
            exerciseId: ex.id,
            exerciseName: ex.name,
            split: ex.split,
            unit: ex.unit,
            targetSets: ex.activeSetsCount,
            loadsUsed: [ex.loads[0], ex.loads.indices.contains(1) ? ex.loads[1] : 0, ex.loads.indices.contains(2) ? ex.loads[2] : 0],
            nextLoads: outcome.loads,
            weightUsed: ex.weight,
            nextTargetWeight: outcome.loads.first ?? ex.weight,
            increment: ex.microIncrement,
            set1Reps: "\(loggedReps[0])",
            set2Reps: "\(loggedReps[1])",
            set3Reps: "\(loggedReps[2])",
            fatigueIndex: ex.fatigueIndex,
            e1RM: ex.e1RM,
            progressionSummary: outcome.summary
        )
        WorkoutStore.shared.appendHistoryEntry(historyEntry)

        self.isRecapShowing = true
        if outcome.s1Adv {
            AudioManager.shared.playFanfare()
        }
        syncLiveActivity()
    }

    public func advanceToNextExerciseAfterRecap() {
        self.isRecapShowing = false
        let list = exercisesForCurrentSplit
        let nextIndex = activeExerciseIndex + 1

        if nextIndex < list.count {
            self.isTransitionRestMode = true
            self.transitionRestRemaining = 120
            self.transitionNextExName = list[nextIndex].name
            startRestTimer(seconds: 120, label: "TRANSITION TO \(list[nextIndex].name.uppercased())", reason: "Inter-Exercise Recovery")
            syncLiveActivity()
        } else {
            self.isRoutineActive = false
            self.isTransitionRestMode = false
            Theme.hapticNotification(.success)
            AudioManager.shared.playFanfare()
            if #available(iOS 16.1, *) {
                LiveActivityManager.shared.endActivity()
            }
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

    private func preparePrescribedRestUI(forSet targetSet: Int, autoStart: Bool) {
        guard let ex = currentExercise else { return }
        let limits = DPOEngine.restLimits[ex.category] ?? RestLimit(min: 90, defaultSec: 120, max: 150)
        let restSec = (targetSet == 2) ? limits.defaultSeconds : limits.minSeconds
        self.restTimerPrescribed = restSec
        self.restTimerRemaining = restSec
        self.restTimerLabel = "REST FOR SET \(targetSet)"
        self.restTimerReason = "\(restSec)s Prescribed Rest"

        if autoStart {
            startRestTimer(seconds: restSec, label: restTimerLabel, reason: restTimerReason)
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

    public func stopRestTimer() {
        self.restTimerRunning = false
        self.restEndTime = nil
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

            if isTransitionRestMode {
                skipTransitionRest()
            } else if isWarmupMode {
                advanceWarmup()
            }
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

        let load = ex.loads.indices.contains(activeSetIndex - 1) ? ex.loads[activeSetIndex - 1] : ex.weight
        let loadText = "\(load) \(ex.unit.uppercased())"
        let targetRepsText = "\(ex.repWindowMin)–\(ex.repWindowMax) Reps"

        let restEnd = restTimerRunning ? restEndTime?.timeIntervalSince1970 : nil

        let contentState = WorkoutActivityAttributes.ContentState(
            splitName: currentSplit.rawValue,
            exerciseName: ex.name,
            setIndex: activeSetIndex,
            totalSets: ex.activeSetsCount,
            loadText: loadText,
            targetRepsText: targetRepsText,
            isResting: restTimerRunning,
            restEndTimestamp: restEnd,
            isTriageLogging: (activeSetIndex == 1 && s1Outcome == nil) || (activeSetIndex == 2 && s2Outcome == nil) || (activeSetIndex == 3 && s3Outcome == nil),
            underTargetText: "< \(ex.repWindowMin) Missed",
            prescribedTargetText: "\(ex.repWindowMin)–\(ex.repWindowMax) Target",
            overloadTargetText: "\(ex.repWindowMax + 1)+ Overload",
            overloadIncrementText: "+\(ex.microIncrement) \(ex.unit)",
            isRecap: isRecapShowing,
            recapLoggedSetsText: "S1: \(loggedReps[0])r • S2: \(loggedReps[1])r • S3: \(loggedReps[2])r",
            recapProgressionHeadline: recapOutcome?.summary ?? "WORKING LOAD CONSOLIDATED",
            recapNextTargetText: "Next Anchor: \(recapOutcome?.loads.first ?? ex.weight) \(ex.unit)",
            recapIsFinalExercise: activeExerciseIndex >= exercisesForCurrentSplit.count - 1,
            isWarmup: isWarmupMode,
            warmupIndex: warmupIndex,
            totalWarmups: totalWarmups,
            warmupTargetText: warmupPrescription?.warmups.indices.contains(warmupIndex - 1) == true ? "\(warmupPrescription!.warmups[warmupIndex - 1].targetReps) reps @ \(warmupPrescription!.warmups[warmupIndex - 1].load) \(ex.unit)" : "",
            isTransitionRest: isTransitionRestMode,
            nextExerciseName: transitionNextExName
        )

        LiveActivityManager.shared.syncWorkoutState(contentState)
    }
}
