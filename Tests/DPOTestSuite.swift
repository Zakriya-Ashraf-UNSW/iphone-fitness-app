import Foundation

// MARK: - Test Suite Runner for DPO PRODSPEC.MD Implementation
// Tests all mathematical rules, edge cases, rest time variations,
// floor clamping invariants, 2-set/3-set mode transitions, and recalibrations.

struct TestReport {
    static var passed = 0
    static var failed = 0
    static var failures: [String] = []

    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
        if actual == expected {
            passed += 1
            print("  ✅ [PASS] \(message)")
        } else {
            failed += 1
            let failMsg = "❌ [FAIL] \(message) -> Expected: \(expected), Got: \(actual) (at \(line))"
            failures.append(failMsg)
            print("  " + failMsg)
        }
    }

    static func assertDoubleClose(_ actual: Double, _ expected: Double, tolerance: Double = 0.05, _ message: String, file: String = #file, line: Int = #line) {
        if abs(actual - expected) <= tolerance {
            passed += 1
            print("  ✅ [PASS] \(message) (\(actual) ≈ \(expected))")
        } else {
            failed += 1
            let failMsg = "❌ [FAIL] \(message) -> Expected: \(expected) ±\(tolerance), Got: \(actual) (at \(line))"
            failures.append(failMsg)
            print("  " + failMsg)
        }
    }

    static func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
        if condition {
            passed += 1
            print("  ✅ [PASS] \(message)")
        } else {
            failed += 1
            let failMsg = "❌ [FAIL] \(message) -> Condition evaluated to false (at \(line))"
            failures.append(failMsg)
            print("  " + failMsg)
        }
    }
}

// MARK: - Test Groups

func testRestLimitsSpecification() {
    print("\n--- TEST GROUP 1: Rest Limits Table (§3) ---")
    let heavy = DPOEngine.restLimits[.heavyCompound]!
    TestReport.assertEqual(heavy.minSeconds, 120, "Heavy Compound min rest = 120s")
    TestReport.assertEqual(heavy.defaultSeconds, 150, "Heavy Compound default rest = 150s")
    TestReport.assertEqual(heavy.maxSeconds, 180, "Heavy Compound max rest = 180s")

    let machine = DPOEngine.restLimits[.machineCompound]!
    TestReport.assertEqual(machine.minSeconds, 75, "Machine Compound min rest = 75s")
    TestReport.assertEqual(machine.defaultSeconds, 90, "Machine Compound default rest = 90s")
    TestReport.assertEqual(machine.maxSeconds, 120, "Machine Compound max rest = 120s")

    let iso = DPOEngine.restLimits[.isolation]!
    TestReport.assertEqual(iso.minSeconds, 45, "Isolation min rest = 45s")
    TestReport.assertEqual(iso.defaultSeconds, 60, "Isolation default rest = 60s")
    TestReport.assertEqual(iso.maxSeconds, 90, "Isolation max rest = 90s")
}

func testRoundToStepAndE1RM() {
    print("\n--- TEST GROUP 2: Rounding & e1RM Calculations (§3) ---")
    // Step rounding
    TestReport.assertDoubleClose(DPOEngine.roundToStep(81.2, step: 2.5), 80.0, "81.2 rounded to 2.5 step = 80.0")
    TestReport.assertDoubleClose(DPOEngine.roundToStep(81.3, step: 2.5), 82.5, "81.3 rounded to 2.5 step = 82.5")
    TestReport.assertDoubleClose(DPOEngine.roundToStep(82.4, step: 2.5), 82.5, "82.4 rounded to 2.5 step = 82.5")
    TestReport.assertDoubleClose(DPOEngine.roundToStep(51.1, step: 1.25), 51.25, "51.1 rounded to 1.25 step = 51.25")

    // e1RM Baechle formula: load * (1 + reps / 30)
    TestReport.assertDoubleClose(DPOEngine.calculateE1RM(load: 100.0, reps: 10.0), 133.3, tolerance: 0.1, "100kg x 10 reps -> e1RM ≈ 133.3kg")
    TestReport.assertDoubleClose(DPOEngine.calculateE1RM(load: 80.0, reps: 6.0), 96.0, tolerance: 0.1, "80kg x 6 reps -> e1RM = 96.0kg")
    TestReport.assertDoubleClose(DPOEngine.calculateE1RM(load: 120.0, reps: 1.0), 124.0, tolerance: 0.1, "120kg x 1 rep -> e1RM = 124.0kg")

    // Fatigue Index: FI = 1 - (r2Actual / r2Expected)
    let e1RM = DPOEngine.calculateE1RM(load: 100.0, reps: 8.0) // 126.7
    let fiNormal = DPOEngine.calculateFatigueIndex(e1RM: e1RM, w2: 80.0, r2Actual: 8.0)
    TestReport.assertTrue(fiNormal > 0.0 && fiNormal < 1.0, "FI is in range (0, 1) when reps drop")

    let fiOverperform = DPOEngine.calculateFatigueIndex(e1RM: 100.0, w2: 80.0, r2Actual: 15.0)
    TestReport.assertDoubleClose(fiOverperform, 0.0, "FI clamped to 0.0 when actual reps exceed expected")
}

func testCalibrationEngine() {
    print("\n--- TEST GROUP 3: Calibration Engine (§5.1) ---")
    let result = DPOEngine.executeCalibration(
        set1Load: 100.0,
        set1Reps: 8,
        set2Load: 80.0,
        set2Reps: 8,
        microIncrement: 2.5
    )
    TestReport.assertDoubleClose(result.e1RM, 126.67, tolerance: 0.2, "Calibration e1RM for 100kg x 8r ≈ 126.67kg")
    TestReport.assertTrue(result.fatigueIndex > 0.50, "Fatigue Index correctly captures ~54% drop")
    TestReport.assertEqual(result.loads[0], 100.0, "Set 1 anchor load is 100.0kg")
    TestReport.assertTrue(result.loads[1] >= 80.0, "Set 2 load clamped to >= 80% floor (80.0kg)")
    TestReport.assertTrue(result.loads[2] >= 60.0, "Set 3 load clamped to >= 60% floor (60.0kg)")
    TestReport.assertEqual(result.activeSetsCount, 3, "Calibrated active sets count is 3")
}

func testDynamicRestAndLoadCoupling() {
    print("\n--- TEST GROUP 4: Dynamic Rest & Load Coupling (§5.2) ---")
    // Fast-paced mode: minSeconds + 15
    let fastHeavy = DPOEngine.resolveSet3Parameters(
        loads: [100.0, 80.0, 65.0],
        category: .heavyCompound,
        microIncrement: 2.5,
        fatigueIndex: 0.10,
        pacingMode: "FAST_PACED"
    )
    TestReport.assertEqual(fastHeavy.restTimerSeconds, 135, "Heavy compound FAST_PACED rest = 120s + 15s = 135s")

    let fastMachine = DPOEngine.resolveSet3Parameters(
        loads: [80.0, 65.0, 50.0],
        category: .machineCompound,
        microIncrement: 2.5,
        fatigueIndex: 0.10,
        pacingMode: "FAST_PACED"
    )
    TestReport.assertEqual(fastMachine.restTimerSeconds, 90, "Machine compound FAST_PACED rest = 75s + 15s = 90s")

    let fastIso = DPOEngine.resolveSet3Parameters(
        loads: [30.0, 25.0, 20.0],
        category: .isolation,
        microIncrement: 1.25,
        fatigueIndex: 0.10,
        pacingMode: "FAST_PACED"
    )
    TestReport.assertEqual(fastIso.restTimerSeconds, 60, "Isolation FAST_PACED rest = 45s + 15s = 60s")

    // Standard mode: defaultSeconds
    let stdHeavy = DPOEngine.resolveSet3Parameters(
        loads: [100.0, 80.0, 65.0],
        category: .heavyCompound,
        microIncrement: 2.5,
        fatigueIndex: 0.10,
        pacingMode: "STANDARD"
    )
    TestReport.assertEqual(stdHeavy.restTimerSeconds, 150, "Heavy compound STANDARD rest = 150s")

    // Fatigue coupling: FI > 0.20 causes candidateW3 to drop toward 60% floor
    let fatigued = DPOEngine.resolveSet3Parameters(
        loads: [100.0, 80.0, 70.0],
        category: .heavyCompound,
        microIncrement: 2.5,
        fatigueIndex: 0.35,
        pacingMode: "FAST_PACED" // clampedRest = 135s <= limits.defaultSeconds (150s)
    )
    TestReport.assertTrue(fatigued.loadDroppedForFatigue, "High fatigue (FI=0.35) with compressed rest triggers preemptive load drop")
    TestReport.assertEqual(fatigued.prescribedLoad, 67.5, "Candidate load 70.0kg dropped by 2.5kg to 67.5kg")

    // Boundary reach: Set 3 hitting minWeight awards +60s compensatory rest
    let boundary = DPOEngine.resolveSet3Parameters(
        loads: [100.0, 80.0, 60.0],
        category: .heavyCompound,
        microIncrement: 2.5,
        fatigueIndex: 0.35,
        pacingMode: "FAST_PACED",
        minWeight: 60.0
    )
    TestReport.assertTrue(boundary.minLimitReached, "minWeight boundary reached")
    TestReport.assertEqual(boundary.restTimerSeconds, 195, "Rest extended by +60s compensatory rest: 135 + 60 = 195s")
}

func testProgressionEngineAndConsolidationGates() {
    print("\n--- TEST GROUP 5: Inter-Session Progression & Gates (§5.3) ---")
    // Scenario 1: S1 hits ceiling, but S2 is NOT consolidated (< 85% of S1)
    // W1 = 100, W2 = 80 (< 85kg floor), W3 = 65 (>= 65kg)
    let s2NotConsolidated = DPOEngine.evaluateProgression(
        loads: [100.0, 80.0, 65.0],
        reps: [10, 8, 8],
        activeSetsCount: 3,
        repMax: 10,
        microIncrement: 2.5
    )
    TestReport.assertEqual(s2NotConsolidated.s1Adv, false, "S1 promotion blocked because Set 2 (80kg) < 85% of Set 1 (85kg)")
    TestReport.assertTrue(s2NotConsolidated.s1HeldReason?.contains("85%") ?? false, "Reason explicitly cites Set 2 85% gate")

    // Scenario 2: S1 hits ceiling, S2 is consolidated (>= 85%), but S3 is NOT consolidated (< 65% of S1)
    // W1 = 100, W2 = 85, W3 = 60 (< 65kg floor)
    let s3NotConsolidated = DPOEngine.evaluateProgression(
        loads: [100.0, 85.0, 60.0],
        reps: [10, 8, 8],
        activeSetsCount: 3,
        repMax: 10,
        microIncrement: 2.5
    )
    TestReport.assertEqual(s3NotConsolidated.s1Adv, false, "S1 promotion blocked because Set 3 (60kg) < 65% of Set 1 (65kg)")
    TestReport.assertTrue(s3NotConsolidated.s1HeldReason?.contains("65%") ?? false, "Reason explicitly cites Set 3 65% gate")

    // Scenario 3: All sets consolidated and S1 cleared repMax -> S1 promoted!
    // W1 = 100, W2 = 85, W3 = 65
    let s1Promoted = DPOEngine.evaluateProgression(
        loads: [100.0, 85.0, 65.0],
        reps: [10, 8, 8],
        activeSetsCount: 3,
        repMax: 10,
        microIncrement: 2.5
    )
    TestReport.assertEqual(s1Promoted.s1Adv, true, "S1 anchor promoted when both 85% and 65% gates are satisfied!")
    TestReport.assertEqual(s1Promoted.loads[0], 102.5, "Next Set 1 load promoted to 102.5kg")

    // Scenario 4: Secondary overload clearing
    // S2 clears repMax -> W2 promoted by microIncrement
    let s2Promoted = DPOEngine.evaluateProgression(
        loads: [100.0, 80.0, 60.0],
        reps: [8, 10, 8],
        activeSetsCount: 3,
        repMax: 10,
        microIncrement: 2.5
    )
    TestReport.assertEqual(s2Promoted.s2Adv, true, "S2 promoted when S2 reps >= repMax")
    TestReport.assertEqual(s2Promoted.loads[1], 82.5, "Set 2 load advances from 80.0kg to 82.5kg")

    // Scenario 5: 2-Set Mode Progression
    let twoSetProg = DPOEngine.evaluateProgression(
        loads: [100.0, 85.0],
        reps: [10, 10],
        activeSetsCount: 2,
        repMax: 10,
        microIncrement: 2.5
    )
    TestReport.assertEqual(twoSetProg.s1Adv, true, "2-Set Mode: S1 promoted with S2 consolidated at 85%")
    TestReport.assertEqual(twoSetProg.loads[0], 102.5, "Next S1 is 102.5kg")

    // Scenario 6: In-Window Target Reps (e.g. 7 or 8 in 6-10 range)
    let inWindowTarget = DPOEngine.evaluateProgression(
        loads: [100.0, 85.0, 65.0],
        reps: [8, 8, 8],
        activeSetsCount: 3,
        repMax: 10,
        microIncrement: 2.5
    )
    TestReport.assertEqual(inWindowTarget.s1Adv, false, "In-window target reps (8r in 6-10 window) does NOT promote Set 1 load")
    TestReport.assertEqual(inWindowTarget.s2Adv, false, "In-window target reps does NOT promote Set 2 load")
    TestReport.assertEqual(inWindowTarget.s3Adv, false, "In-window target reps does NOT promote Set 3 load")
    TestReport.assertEqual(inWindowTarget.loads[0], 100.0, "Working load held at exactly 100.0kg")
}

func testMissedRepsAndRestAdjustments() {
    print("\n--- TEST GROUP 6: Failure & Drop Handling: HANDLE_MISSED_REPS (§5.4) ---")
    // Branch 1: Set 1 Missed Threshold
    // S1 missed: W1 drops by -S, W2 & W3 floor clamped, awards +60s compensatory rest
    let s1Missed = DPOEngine.handleMissedReps(
        loads: [100.0, 80.0, 60.0],
        reps: [5, 8, 8], // repMin = 6
        activeSetsCount: 3,
        repMin: 6,
        microIncrement: 2.5
    )
    TestReport.assertEqual(s1Missed.loads[0], 97.5, "Set 1 deloaded from 100.0kg to 97.5kg")
    TestReport.assertEqual(s1Missed.extraSeconds, 60, "Set 1 failure awards +60s compensatory rest")

    // Branch 2A: Set 2 Missed Above Floor
    // W1 = 100, W2 = 85 (Floor = 80). Drop: W2 = 82.5 >= 80. extraSeconds = 0.
    let s2Drop = DPOEngine.handleMissedReps(
        loads: [100.0, 85.0, 60.0],
        reps: [8, 5, 8],
        activeSetsCount: 3,
        repMin: 6,
        microIncrement: 2.5
    )
    TestReport.assertEqual(s2Drop.loads[1], 82.5, "Set 2 dropped by -2.5kg to 82.5kg")
    TestReport.assertEqual(s2Drop.extraSeconds, 0, "No extra rest when load can drop mechanically")

    // Branch 2B: Set 2 Hit 80% Floor Boundary
    // W1 = 100, W2 = 80 (Floor = 80). Cannot drop below 80! Hold load and award +60s compensatory rest!
    let s2Floor = DPOEngine.handleMissedReps(
        loads: [100.0, 80.0, 60.0],
        reps: [8, 5, 8],
        activeSetsCount: 3,
        repMin: 6,
        microIncrement: 2.5
    )
    TestReport.assertEqual(s2Floor.loads[1], 80.0, "Set 2 held at 80% floor boundary")
    TestReport.assertEqual(s2Floor.extraSeconds, 60, "80% floor boundary hit awards +60s compensatory rest!")

    // Branch 3A: Set 3 Missed Above Floor
    // W1 = 100, W3 = 65 (Floor = 60). Drop: W3 = 62.5 >= 60. extraSeconds = 0.
    let s3Drop = DPOEngine.handleMissedReps(
        loads: [100.0, 80.0, 65.0],
        reps: [8, 8, 5],
        activeSetsCount: 3,
        repMin: 6,
        microIncrement: 2.5,
        consecutiveFailures: 0
    )
    TestReport.assertEqual(s3Drop.loads[2], 62.5, "Set 3 dropped by -2.5kg to 62.5kg")
    TestReport.assertEqual(s3Drop.consecutiveFailures, 0, "Consecutive failures reset to 0")

    // Branch 3B: Set 3 Hit 60% Floor Boundary (1st failure)
    // W1 = 100, W3 = 60 (Floor = 60). Cannot drop below 60. consecutiveFailures becomes 1, +60s rest awarded.
    let s3FloorFirst = DPOEngine.handleMissedReps(
        loads: [100.0, 80.0, 60.0],
        reps: [8, 8, 5],
        activeSetsCount: 3,
        repMin: 6,
        microIncrement: 2.5,
        consecutiveFailures: 0
    )
    TestReport.assertEqual(s3FloorFirst.loads[2], 60.0, "Set 3 load held at 60% floor")
    TestReport.assertEqual(s3FloorFirst.consecutiveFailures, 1, "Consecutive failure count increments to 1")
    TestReport.assertEqual(s3FloorFirst.extraSeconds, 60, "First 60% floor breach awards +60s compensatory rest!")
    TestReport.assertEqual(s3FloorFirst.activeSetsCount, 3, "Still in 3-set mode on first warning")

    // Branch 3C: Set 3 Hit 60% Floor Boundary (2nd consecutive failure!)
    // Consecutive failures >= 1 -> Mode transition: drop to 2-Set mode!
    let s3FloorSecond = DPOEngine.handleMissedReps(
        loads: [100.0, 80.0, 60.0],
        reps: [8, 8, 5],
        activeSetsCount: 3,
        repMin: 6,
        microIncrement: 2.5,
        consecutiveFailures: 1
    )
    TestReport.assertEqual(s3FloorSecond.activeSetsCount, 2, "DROPPED TO 2-SET MODE upon consecutive 60% floor breach!")
    TestReport.assertEqual(s3FloorSecond.consecutiveFailures, 0, "Consecutive failures reset after dropping to 2-set mode")
}

func testSet3ReEntryGate() {
    print("\n--- TEST GROUP 7: Set 3 Re-Entry Gate (§5.5) ---")
    // Gate 1 Fail: Set 2 load < 85% of Set 1
    let s1 = DPOEngine.SessionPerformanceHistory(set1Load: 100.0, set1Reps: 10, set2Load: 80.0, set2Reps: 10) // 80 < 85
    let s2 = DPOEngine.SessionPerformanceHistory(set1Load: 100.0, set1Reps: 10, set2Load: 85.0, set2Reps: 10)
    let g1Fail = DPOEngine.evaluateSet3Reentry(currentW1: 100.0, microIncrement: 2.5, repWindowMax: 10, lastTwoSessions: [s1, s2])
    TestReport.assertEqual(g1Fail.canReEnable, false, "Gate 1 Fail: Set 2 load ratio < 85% in session 1")

    // Gate 2 Fail: Rep drop > 2 reps (e.g. S1 = 10, S2 = 7)
    let s3 = DPOEngine.SessionPerformanceHistory(set1Load: 100.0, set1Reps: 10, set2Load: 85.0, set2Reps: 7) // drop = 3
    let s4 = DPOEngine.SessionPerformanceHistory(set1Load: 100.0, set1Reps: 10, set2Load: 85.0, set2Reps: 10)
    let g2Fail = DPOEngine.evaluateSet3Reentry(currentW1: 100.0, microIncrement: 2.5, repWindowMax: 10, lastTwoSessions: [s3, s4])
    TestReport.assertEqual(g2Fail.canReEnable, false, "Gate 2 Fail: Rep drop > 2 reps in session 1")

    // Gate 3 Fail: Set 2 did not clear rep ceiling (< 10 reps)
    let s5 = DPOEngine.SessionPerformanceHistory(set1Load: 100.0, set1Reps: 10, set2Load: 85.0, set2Reps: 9)
    let s6 = DPOEngine.SessionPerformanceHistory(set1Load: 100.0, set1Reps: 10, set2Load: 85.0, set2Reps: 10)
    let g3Fail = DPOEngine.evaluateSet3Reentry(currentW1: 100.0, microIncrement: 2.5, repWindowMax: 10, lastTwoSessions: [s5, s6])
    TestReport.assertEqual(g3Fail.canReEnable, false, "Gate 3 Fail: Set 2 did not clear ceiling in session 1")

    // All 3 Gates Passed for both sessions:
    // S1: 100kg x 10, S2: 85kg x 10 (ratio 85%, drop 0, reps 10)
    // S1: 100kg x 10, S2: 87.5kg x 10 (ratio 87.5%, drop 0, reps 10)
    let pass1 = DPOEngine.SessionPerformanceHistory(set1Load: 100.0, set1Reps: 10, set2Load: 85.0, set2Reps: 10)
    let pass2 = DPOEngine.SessionPerformanceHistory(set1Load: 100.0, set1Reps: 10, set2Load: 87.5, set2Reps: 10)
    let reEnabled = DPOEngine.evaluateSet3Reentry(currentW1: 100.0, microIncrement: 2.5, repWindowMax: 10, lastTwoSessions: [pass1, pass2])
    TestReport.assertEqual(reEnabled.canReEnable, true, "All 3 gates passed! Set 3 re-entry allowed!")
    TestReport.assertEqual(reEnabled.initialW3, 65.0, "Initial Set 3 soft-entry load is 65% of 100kg = 65.0kg")
}

func testPeriodicRecalibration() {
    print("\n--- TEST GROUP 8: Periodic Recalibration (§5.6) ---")
    // e1RM = 100.0kg. Test load = 80kg.
    // Predicted reps = round(30 * ((100 / 80) - 1)) = round(30 * 0.25) = 7.5 -> 8 reps.

    // Case 1: Supercompensation (delta >= +2, e.g. 10 reps)
    let superComp = DPOEngine.evaluateRecalibration(currentE1RM: 100.0, testLoad: 80.0, actualReps: 10)
    TestReport.assertEqual(superComp.status, .supercompensation, "delta = +2 triggers SUPERCOMPENSATION")
    TestReport.assertDoubleClose(superComp.e1RM, 106.67, tolerance: 0.1, "New e1RM upgraded to 106.67kg")

    // Case 2: Fatigue Flag (delta <= -2, e.g. 5 reps)
    let fatigueFlag = DPOEngine.evaluateRecalibration(currentE1RM: 100.0, testLoad: 80.0, actualReps: 5)
    TestReport.assertEqual(fatigueFlag.status, .fatigueFlag, "delta = -3 triggers FATIGUE_FLAG")
    TestReport.assertEqual(fatigueFlag.e1RM, 100.0, "e1RM held without upgrade during fatigue flag")

    // Case 3: Verified (delta within [-1, +1], e.g. 8 reps)
    let verified = DPOEngine.evaluateRecalibration(currentE1RM: 100.0, testLoad: 80.0, actualReps: 8)
    TestReport.assertEqual(verified.status, .verified, "delta = 0 status is VERIFIED")
    TestReport.assertDoubleClose(verified.e1RM, 101.33, tolerance: 0.1, "New e1RM updated accurately to 101.33kg")
}

// MARK: - Main Execution

@main
struct DPOTestRunner {
    static func main() {
        print("=================================================================")
        print("  DPO PRODSPEC.MD MATHEMATICAL VERIFICATION & TEST HARNESS")
        print("=================================================================")

        testRestLimitsSpecification()
        testRoundToStepAndE1RM()
        testCalibrationEngine()
        testDynamicRestAndLoadCoupling()
        testProgressionEngineAndConsolidationGates()
        testMissedRepsAndRestAdjustments()
        testSet3ReEntryGate()
        testPeriodicRecalibration()

        print("\n=================================================================")
        print("  FINAL RESULTS: \(TestReport.passed) PASSED, \(TestReport.failed) FAILED")
        print("=================================================================")

        if TestReport.failed > 0 {
            print("\nFAILURES:")
            for f in TestReport.failures {
                print(f)
            }
            exit(1)
        } else {
            print("\n🎉 ALL TESTS PASSED WITH 100% SPEC-001 COMPLIANCE! 🎉\n")
            exit(0)
        }
    }
}
