---

# SPEC-001: Dynamic Progressive Overload (DPO) Hypertrophy Engine

## 1. System Metadata & Context

* **System ID:** `DPO-ENGINE-HYPERTROPHY-V1`
* **Target Audience:** Systems Architects, LLM Code Generators, Mobile App Developers.
* **Goal:** Algorithmic calculation of resistance training loads, rep targets, sets, rest intervals, and volume states without subjective RIR entry or bar-speed tracking hardware. Fully supports mixed units (`KG` and `LBS`) and per-exercise micro-increments.

---

## 2. Invariants & Mathematical Formulations

```
+-------------------------------------------------------------------------+
|                          STRUCTURAL INVARIANTS                          |
|                                                                         |
|   W_1 >= W_2 >= W_3                                                     |
|   W_2 >= Floor(W_2) = roundToStep(0.80 * W_1, config.microIncrement)   |
|   W_3 >= Floor(W_3) = roundToStep(0.60 * W_1, config.microIncrement)   |
|                                                                         |
|   Where:                                                                |
|     W_1  = Anchor Load (Set 1)                                          |
|     W_2  = Intermediate Load (Set 2)                                    |
|     W_3  = Base Load (Set 3)                                            |
|     All calculations execute strictly in config.unit (KG or LBS)        |
+-------------------------------------------------------------------------+

```

### 2.1 Rounding to Discretized Equipment Step

$$\text{roundToStep}(X, S) = \text{round}\left(\frac{X}{S}\right) \times S$$


*Where $X$ is raw calculated weight, and $S$ is `config.microIncrement` in native units.*

### 2.2 Submaximal e1RM (0 RIR)

$$\text{e1RM} = W \times \left(1 + \frac{R}{30}\right)$$


*Where $W$ is load in `config.unit`, and $R$ is completed reps to muscular failure.*

### 2.3 Normalized Fatigue Index ($FI$)

Measured in a 2-set sequence with a mandatory **180s rest interval** and a **20% load drop ($W_2 = 0.80 \times W_1$)**:

1. Theoretical un-fatigued capacity at $W_2$:

$$R_{2,\text{expected}} = 30 \times \left(\frac{\text{e1RM}}{W_2} - 1\right)$$


2. Normalized Fatigue Ratio:

$$FI = \text{clamp}\left(1 - \frac{R_{2,\text{actual}}}{R_{2,\text{expected}}}, \quad 0.0, \quad 1.0\right)$$



### 2.4 Recalibration Failure Prediction

$$R_{\text{predicted}} = \text{round}\left(30 \times \left(\frac{\text{e1RM}}{W_1} - 1\right)\right)$$

$$\Delta_{\text{perf}} = R_{\text{actual}} - R_{\text{predicted}}$$

### 2.5 Unit Conversion & Display Helpers

```
CONSTANT KG_TO_LBS = 2.20462262
CONSTANT LBS_TO_KG = 0.45359237

FUNCTION CONVERT_WEIGHT(value, fromUnit, toUnit):
    IF fromUnit == toUnit:
        RETURN value
    ENDIF
    IF fromUnit == "KG" AND toUnit == "LBS":
        RETURN value * KG_TO_LBS
    ENDIF
    IF fromUnit == "LBS" AND toUnit == "KG":
        RETURN value * LBS_TO_KG
    ENDIF
END FUNCTION

```

---

## 3. Abstract Schema Definitions

```yaml
WeightUnit:
  Enum: ["KG", "LBS"]

ExerciseCategory:
  Enum: ["HEAVY_COMPOUND", "MACHINE_COMPOUND", "ISOLATION"]

EquipmentType:
  Enum: ["BARBELL", "DUMBBELL", "CABLE_STACK", "MACHINE_LEVER", "BODYWEIGHT_LOADED"]

PacingMode:
  Enum: ["FAST_PACED", "STANDARD"]

RestLimits:
  HEAVY_COMPOUND:
    minSeconds: 120
    defaultSeconds: 150
    maxSeconds: 180
  MACHINE_COMPOUND:
    minSeconds: 75
    defaultSeconds: 90
    maxSeconds: 120
  ISOLATION:
    minSeconds: 45
    defaultSeconds: 60
    maxSeconds: 90

UserSettings:
  defaultUnit: WeightUnit       # Fallback unit when creating new exercises
  allowMixedUnits: Boolean      # Allows per-exercise unit independence (Default: true)
  pacingMode: PacingMode        # Global or per-session pacing mode (Default: "FAST_PACED")

ExerciseConfig:
  id: String
  name: String
  category: ExerciseCategory
  equipmentType: EquipmentType
  unit: WeightUnit              # "KG" or "LBS" (Independently selected per exercise)
  microIncrement: Float         # Increment step in native unit (e.g., 1.25 for KG, 2.5/5.0 for LBS)
  repWindowMin: Integer         # R_min (e.g., 6 or 8)
  repWindowMax: Integer         # R_max (e.g., 9 or 12)

ExerciseState:
  exerciseId: String
  unit: WeightUnit              # Mirrors config.unit at time of state tracking
  isCalibrated: Boolean
  e1RM: Float                   # Stored in native unit
  fatigueIndex: Float           # 0.0 <= FI <= 1.0
  activeSetsCount: Integer      # 2 or 3
  loads: Array[Float, Float, Float] # [W1, W2, W3] in native unit
  consecutiveSet3Failures: Integer
  consecutiveStagnations: Integer
  sessionsSinceRecalibration: Integer

SetPerformance:
  load: Float                   # In native unit
  reps: Integer

```

---

## 4. Equipment Defaults Table

When a user creates an exercise, initialize `unit` and `microIncrement` with these defaults based on `EquipmentType` and `UserSettings.defaultUnit`:

| Equipment Type | Default Unit = `KG` | Default Unit = `LBS` | Typical Use Case |
| --- | --- | --- | --- |
| **BARBELL** | `unit: "KG"`, `step: 1.25` | `unit: "LBS"`, `step: 2.5` | Standard fractional Olympic plates |
| **DUMBBELL** | `unit: "KG"`, `step: 2.0` | `unit: "LBS"`, `step: 5.0` | Fixed gym dumbbell racks |
| **CABLE_STACK** | `unit: "KG"`, `step: 2.5` | `unit: "LBS"`, `step: 5.0` | Pin-selected selectorized stacks |
| **MACHINE_LEVER** | `unit: "KG"`, `step: 2.5` | `unit: "LBS"`, `step: 5.0` | Plate-loaded machines (e.g., Smith Machine) |
| **BODYWEIGHT_LOADED** | `unit: "KG"`, `step: 1.25` | `unit: "LBS"`, `step: 2.5` | Weighted pull-ups / dips |

---

## 5. Pipeline Logic Specifications

### 5.1 Calibration Engine: `EXECUTE_CALIBRATION`

```
FUNCTION EXECUTE_CALIBRATION(config, set1, set2):
    // Precondition: Both sets performed to 0 RIR with 180s rest.
    // Precondition: set1.load and set2.load are in config.unit
    // Precondition: set2.load == roundToStep(set1.load * 0.80, config.microIncrement)
    
    e1RM = set1.load * (1.0 + (set1.reps / 30.0))
    R2_expected = 30.0 * ((e1RM / set2.load) - 1.0)
    
    rawFI = 0.0
    IF R2_expected > 0.0:
        rawFI = 1.0 - (set2.reps / R2_expected)
    ENDIF
    FI = clamp(rawFI, 0.0, 1.0)
    
    W1 = set1.load
    W2_ratio = max(0.80, 1.0 - (FI * 0.5))
    W3_ratio = max(0.60, 1.0 - (FI * 1.0))
    
    W2 = roundToStep(W1 * W2_ratio, config.microIncrement)
    W3 = roundToStep(W1 * W3_ratio, config.microIncrement)
    
    RETURN ExerciseState {
        exerciseId: config.id,
        unit: config.unit,
        isCalibrated: TRUE,
        e1RM: round(e1RM, 2),
        fatigueIndex: round(FI, 3),
        activeSetsCount: 3,
        loads: [W1, W2, W3],
        consecutiveSet3Failures: 0,
        consecutiveStagnations: 0,
        sessionsSinceRecalibration: 0
    }
END FUNCTION

```

---

### 5.2 Dynamic Rest & Load Coupling Engine: `RESOLVE_SET3_PARAMETERS`

```
FUNCTION RESOLVE_SET3_PARAMETERS(state, config, pacingMode):
    limits = RestLimits[config.category]
    
    IF pacingMode == "FAST_PACED":
        targetRest = limits.minSeconds + 15
    ELSE:
        targetRest = limits.defaultSeconds
    ENDIF
    
    clampedRest = min(targetRest, limits.maxSeconds)
    floorW3 = roundToStep(state.loads[0] * 0.60, config.microIncrement)
    candidateW3 = state.loads[2]
    
    // Preemptively drop load toward floor if rest is compressed and fatigue index is notable
    IF clampedRest <= limits.defaultSeconds AND state.fatigueIndex > 0.20:
        candidateW3 = max(floorW3, candidateW3 - config.microIncrement)
    ENDIF
    
    prescribedW3 = max(floorW3, candidateW3)
    
    RETURN {
        restTimerSeconds: clampedRest,
        prescribedLoad: prescribedW3,
        unit: config.unit
    }
END FUNCTION

```

---

### 5.3 Inter-Session Progression: `EVALUATE_PROGRESSION`

```
FUNCTION EVALUATE_PROGRESSION(state, config, repsCompleted):
    // Precondition: All completed reps are >= config.repWindowMin
    [W1, W2, W3] = state.loads
    [R1, R2, R3] = repsCompleted
    S = config.microIncrement
    R_max = config.repWindowMax
    
    IF state.activeSetsCount == 3:
        // 1. Evaluate Set 3 (Bottom Overload Driver)
        IF R3 >= R_max:
            IF (W3 + S) <= W2:
                W3 = W3 + S
            ENDIF
        ENDIF
        
        // 2. Evaluate Set 2 (Intermediate Driver)
        IF R2 >= R_max:
            IF (W2 + S) <= W1:
                W2 = W2 + S
            ENDIF
        ENDIF
        
        // 3. Evaluate Set 1 (Anchor Driver - requires foundation consolidation)
        set2Consolidated = (W2 >= W1 * 0.85)
        set3Consolidated = (W3 >= W1 * 0.65)
        IF R1 >= R_max AND set2Consolidated AND set3Consolidated:
            W1 = W1 + S
        ENDIF
        
        // 4. Invariant Clamping
        W2 = max(W2, roundToStep(W1 * 0.80, S))
        W3 = max(W3, roundToStep(W1 * 0.60, S))
        
    ELSE: // activeSetsCount == 2
        IF R2 >= R_max:
            IF (W2 + S) <= W1:
                W2 = W2 + S
            ENDIF
        ENDIF
        
        IF R1 >= R_max AND (W2 >= W1 * 0.85):
            W1 = W1 + S
        ENDIF
        
        W2 = max(W2, roundToStep(W1 * 0.80, S))
    ENDIF
    
    RETURN [W1, W2, W3]
END FUNCTION

```

---

### 5.4 Failure & Drop Handling: `HANDLE_MISSED_REPS`

```
FUNCTION HANDLE_MISSED_REPS(state, config, repsCompleted):
    // Precondition: At least one set completed reps < config.repWindowMin
    [W1, W2, W3] = state.loads
    [R1, R2, R3] = repsCompleted
    S = config.microIncrement
    R_min = config.repWindowMin
    
    // Branch 1: Anchor Set 1 Failed
    IF R1 < R_min:
        W1 = max(S, W1 - S)
        W2 = min(W2, W1)
        W3 = min(W3, W2)
        state.loads = [W1, W2, W3]
        state.consecutiveStagnations = state.consecutiveStagnations + 1
        RETURN { state: state, restAdjustment: null }
    ENDIF
    
    // Branch 2: Intermediate Set 2 Failed
    IF R2 < R_min:
        floor2 = roundToStep(W1 * 0.80, S)
        IF (W2 - S) >= floor2:
            W2 = W2 - S
            W3 = min(W3, W2)
            state.loads = [W1, W2, W3]
            RETURN { state: state, restAdjustment: null }
        ELSE:
            // Hit 80% floor boundary: Hold load, add rest interval
            RETURN { state: state, restAdjustment: { setIndex: 2, extraSeconds: 60 } }
        ENDIF
    ENDIF
    
    // Branch 3: Base Set 3 Failed (3-set mode only)
    IF state.activeSetsCount == 3 AND R3 < R_min:
        floor3 = roundToStep(W1 * 0.60, S)
        IF (W3 - S) >= floor3:
            W3 = W3 - S
            state.loads = [W1, W2, W3]
            state.consecutiveSet3Failures = 0
            RETURN { state: state, restAdjustment: null }
        ELSE:
            // 60% Floor Breach Event
            IF state.consecutiveSet3Failures >= 1:
                state.activeSetsCount = 2
                state.consecutiveSet3Failures = 0
                RETURN { state: state, restAdjustment: null }
            ELSE:
                state.consecutiveSet3Failures = 1
                RETURN { state: state, restAdjustment: { setIndex: 3, extraSeconds: 60 } }
            ENDIF
        ENDIF
    ENDIF
    
    RETURN { state: state, restAdjustment: null }
END FUNCTION

```

---

### 5.5 Set 3 Re-Entry Gate: `EVALUATE_SET3_REENTRY`

```
FUNCTION EVALUATE_SET3_REENTRY(state, config, lastTwoSessions):
    // Precondition: state.activeSetsCount == 2
    IF length(lastTwoSessions) < 2:
        RETURN { canReEnable: FALSE, initialW3: 0.0 }
    ENDIF
    
    FOR session IN lastTwoSessions:
        // Gate 1: Set 2 load ratio >= 85% of Set 1
        IF session.set2.load < (session.set1.load * 0.85):
            RETURN { canReEnable: FALSE, initialW3: 0.0 }
        ENDIF
        // Gate 2: Intersession fatigue drop <= 2 reps
        IF (session.set1.reps - session.set2.reps) > 2:
            RETURN { canReEnable: FALSE, initialW3: 0.0 }
        ENDIF
        // Gate 3: Set 2 cleared rep ceiling
        IF session.set2.reps < config.repWindowMax:
            RETURN { canReEnable: FALSE, initialW3: 0.0 }
        ENDIF
    ENDFOR
    
    // Re-enter at soft-entry 65% anchor load
    softEntryW3 = roundToStep(state.loads[0] * 0.65, config.microIncrement)
    RETURN { canReEnable: TRUE, initialW3: softEntryW3 }
END FUNCTION

```

---

### 5.6 Periodic Recalibration: `EVALUATE_RECALIBRATION`

```
FUNCTION EVALUATE_RECALIBRATION(state, testLoad, actualReps):
    // Precondition: testLoad is in state.unit
    predictedReps = round(30.0 * ((state.e1RM / testLoad) - 1.0))
    delta = actualReps - predictedReps
    newE1RM = testLoad * (1.0 + (actualReps / 30.0))
    
    IF delta >= 2:
        state.e1RM = round(newE1RM, 2)
        state.consecutivePromotions = state.consecutivePromotions + 1
        state.sessionsSinceRecalibration = 0
        RETURN { state: state, status: "SUPERCOMPENSATION" }
    ELSE IF delta <= -2:
        state.consecutiveStagnations = state.consecutiveStagnations + 1
        RETURN { state: state, status: "FATIGUE_FLAG" }
    ELSE:
        state.e1RM = round(newE1RM, 2)
        state.sessionsSinceRecalibration = 0
        RETURN { state: state, status: "VERIFIED" }
    ENDIF
END FUNCTION

```

---

## 6. End-to-End Execution Flowchart

```
                 [ User Starts Session ]
                            |
                 Is isCalibrated == TRUE?
                 /                      \
             [No]                        [Yes]
              /                            \
   [ EXECUTE_CALIBRATION ]       Check Recalibration Trigger
   - Set 1: Load to failure      (sessionsSinceRecalibration >= 5)
   - Rest: Exactly 180s                    /             \
   - Set 2: 80% Load to failure        [Yes]             [No]
   - Compute e1RM & FI                  /                 \
                               [ RECALIBRATION ]   [ STANDARD SESSION ]
                               Set 1 to failure    - Set 1: W1 (native unit)
                               Evaluate delta      - Set 2: W2 (native unit)
                                                   - If activeSetsCount == 3:
                                                       RESOLVE_SET3_PARAMETERS()
                                                       Set 3: W3 (native unit)
                                                          |
                                                          v
                                               [ Post-Session Check ]
                                               Did any set miss R_min?
                                                   /             \
                                               [Yes]             [No]
                                                /                 \
                                      HANDLE_MISSED_REPS()   EVALUATE_PROGRESSION()
                                                                  |
                                                             If sets == 2:
                                                             EVALUATE_SET3_REENTRY()

```

---

## 7. Implementation Invariant Verification Checklist

Prior to committing state updates to database or memory stores, the application runtime MUST assert:

* [ ] **Unit Check:** Does `state.unit === config.unit` evaluate to `true`?
* [ ] **Floor Check 1:** Does $W_2 \ge \text{roundToStep}(W_1 \times 0.80, \; \text{config.microIncrement})$ evaluate to `true`?
* [ ] **Floor Check 2 (if 3 sets active):** Does $W_3 \ge \text{roundToStep}(W_1 \times 0.60, \; \text{config.microIncrement})$ evaluate to `true`?
* [ ] **Order Check:** Does $W_1 \ge W_2 \ge W_3$ evaluate to `true`?
* [ ] **Rest Check:** Does the prescribed rest timer before Set 3 stay $\le T_{\text{max}}$ for that exercise category?
* [ ] **Progression Gate:** Does Set 1 hold its weight if Set 2 is $< 85\%$ of Set 1 or Set 3 is $< 65\%$ of Set 1?

### 8. Invariants & Rules

* **Load Ceiling:** For every warm-up set $i$, $\text{Load}_i < W_1$ (must remain strictly lower than the anchor working load).
* **Equipment Minimum:** $\text{Load}_i \ge \text{baseTareWeight}$ (e.g., standard Olympic bar tare of 20 kg / 45 lb).
* **Fatigue Prevention:** Rep counts must taper downward ($10 \rightarrow 4 \rightarrow 1$), with all sets performed at $\ge 4\text{ RIR}$ to avoid accumulating metabolites before working sets.
* **Minimum Threshold:** Skip warm-ups entirely if $W_1 \le 15\text{ kg}$ ($35\text{ lb}$).

---

### 9. Warm-Up Tier Resolution

Determine the volume and intensity of warm-up sets based on exercise category and session order:

```
FUNCTION RESOLVE_WARMUP_TIER(config, context):
    isFirstForMuscle = NOT (config.muscleGroup IN context.previousMuscleGroupsWorked)
    
    IF config.category IN ["HEAVY_COMPOUND", "MACHINE_COMPOUND"]:
        IF isFirstForMuscle:
            RETURN "FULL_RAMP"      // 3 ramp sets: neural potentiation + pattern prep
        ELSE:
            RETURN "ACCUSTOMED"     // 2 priming sets: joint & friction check only
        ENDIF
    ELSE // ISOLATION
        IF isFirstForMuscle:
            RETURN "PRIMING"        // 1 light set: tendon/line-of-pull check
        ELSE:
            RETURN "NONE"           // Already fatigued/warmed; 0 warm-up sets
        ENDIF
    ENDIF
END FUNCTION

```

---

### 10. Generation Logic

```
FUNCTION GENERATE_WARMUP_PRESCRIPTION(state, config, context):
    W1 = state.loads[0]
    S = config.microIncrement
    minTare = config.baseTareWeight
    tier = RESOLVE_WARMUP_TIER(config, context)
    warmups = []
    
    threshold = (config.unit == "KG") ? 15.0 : 35.0
    IF W1 <= threshold OR tier == "NONE":
        RETURN warmups
    ENDIF
    
    // -------------------------------------------------------------
    // TIER 1: FULL_RAMP (First Compound: 50% -> 70% -> 87.5%)
    // -------------------------------------------------------------
    IF tier == "FULL_RAMP":
        p1 = max(minTare, roundToStep(W1 * 0.50, S))
        p2 = max(p1 + S, roundToStep(W1 * 0.70, S))
        p3 = max(p2 + S, roundToStep(W1 * 0.875, S))
        
        IF p1 < W1:
            warmups.append({ setIndex: 1, targetReps: 10, load: p1, restSeconds: 60 })
        ENDIF
        IF p2 < W1 AND p2 > p1:
            warmups.append({ setIndex: 2, targetReps: 4,  load: p2, restSeconds: 75 })
        ENDIF
        IF p3 < W1 AND p3 > p2:
            warmups.append({ setIndex: 3, targetReps: 1,  load: p3, restSeconds: 90 })
        ENDIF

    // -------------------------------------------------------------
    // TIER 2: ACCUSTOMED (Subsequent Compound: 60% -> 85%)
    // -------------------------------------------------------------
    ELSE IF tier == "ACCUSTOMED":
        p1 = max(minTare, roundToStep(W1 * 0.60, S))
        p2 = max(p1 + S, roundToStep(W1 * 0.85, S))
        
        IF p1 < W1:
            warmups.append({ setIndex: 1, targetReps: 6, load: p1, restSeconds: 60 })
        ENDIF
        IF p2 < W1 AND p2 > p1:
            warmups.append({ setIndex: 2, targetReps: 2, load: p2, restSeconds: 75 })
        ENDIF

    // -------------------------------------------------------------
    // TIER 3: PRIMING (First Isolation: 60%)
    // -------------------------------------------------------------
    ELSE IF tier == "PRIMING":
        p1 = max(minTare, roundToStep(W1 * 0.60, S))
        
        IF p1 < W1:
            warmups.append({ setIndex: 1, targetReps: 8, load: p1, restSeconds: 45 })
        ENDIF
    ENDIF
    
    RETURN warmups
END FUNCTION

```

---

### 11. Assisted Exercises & Load Reduction Protocol

For exercises using counterweight or assistance pins (such as Assisted Pull-Ups or Assisted Dips):

#### 11.1 Assistance Invariants & Physical Machine Reality
1. **Inverse Overload Dynamics**: Getting stronger reduces the assistance pin weight ($-S$), requiring the athlete to lift more of their actual bodyweight.
2. **Machine Counterweight Mechanics**:
   - On an assisted machine, a **higher weight pin** provides **more assistance** (easiest counterweight).
   - A **lower weight pin** provides **less assistance** (hardest counterweight, closest to unassisted bodyweight).
   - Therefore, the selectorized stack has both a **Lowest Assistance Floor (`minWeight`)** and a **Highest Assistance Ceiling (`maxWeight`)**.
3. **Fatigue Accommodation**: In an assisted exercise, fatigue causes subsequent sets to require *equal or higher* assistance, bounded by the machine's maximum assistance stack:
   $$\min(minWeight) \le A_1 \le A_2 \le A_3 \le maxWeight$$
   - **Set 1 (Anchor Assistance)**: Lowest assistance pin (hardest set, maximum raw output).
   - **Set 2 (Intermediate Assistance)**: $+20\text{–}25\%$ higher assistance to maintain volume in presence of muscular fatigue, clamped to $maxWeight$.
   - **Set 3 (Base Assistance)**: $+45\text{–}50\%$ higher assistance for final hypertrophy burn, clamped to $maxWeight$.

#### 11.2 Progression & Failure Rules for Assisted Mode
- **Ceiling Breakthrough ($R \ge R_{max}$)**:
  - If Set 1 clears rep ceiling: Decrement assistance pin ($A_1 \leftarrow \max(minWeight, A_1 - S)$).
  - If Set 2 or Set 3 clears ceiling: Decrement respective set assistance pin ($A_i \leftarrow \max(minWeight, A_i - S)$) to close the assistance gap toward Set 1.
- **Missed Reps ($R < R_{min}$)**:
  - If reps are missed on Set 1 or Set 2: The exercise was too heavy. Increment assistance pin ($A_i \leftarrow \min(maxWeight, A_i + S)$).
  - Set 3 Under-8 1st Warning: Increment assistance ($A_3 \leftarrow \min(maxWeight, A_3 + S)$) and extend rest by $+60$s.
  - Set 3 Under-8 2nd Consecutive Warning: Floor breach trigger; auto-transition to 2-Set mode.
  - **Stack Ceiling Clamping**: If an assistance increment would exceed `maxWeight`, the algorithm clamps to `maxWeight`, notifies the user of the equipment assistance limit, and awards compensatory rest ($+60$s) rather than prescribing an impossible higher counterweight.
- **Milestone Graduation**: When Set 1 reaches machine minimum assistance floor ($A_1 \le minWeight$, typically $\le 5$ lbs or 0 lbs counterweight), the user achieves the milestone and is prompted to graduate to **Unassisted Bodyweight Pull-Ups**.

---

### 12. Equipment Constraints: Machine Weight Limits (`minWeight` & `maxWeight`)

#### 12.1 Floor and Ceiling Definitions
Weight-stack and lever machines possess physical resistance boundaries:
- **`minWeight` (Floor)**:
  - Free weights / Standard machines: Physical lowest pin or plate (e.g. 5 lbs, 10 lbs, or 0 lbs). Prevents deload drops below equipment floor.
  - Assisted lifts: Minimum assistance pin before free bodyweight (e.g. 5 lbs / 2.5 kg).
- **`maxWeight` (Ceiling / Highest Assistance Limit)**:
  - Assisted lifts: Highest selectorized weight plate on the counterweight stack (default 100 lbs / 50 kg). The algorithm will never prescribe assistance higher than this physical machine ceiling.

#### 12.2 Equipment Clamping & Compensatory Rest
1. **Load Clamping Invariant**:
   - Standard lifts: $W_{\text{prescribed}} = \max(minWeight, W_{\text{candidate}})$
   - Assisted lifts: $W_{\text{prescribed}} = \max(minWeight, \min(maxWeight, W_{\text{candidate}}))$
2. **Compensatory Rest Adjustment**: When fatigue calculations, calibration, or missed reps reach equipment boundaries (`minWeight` floor or `maxWeight` assistance ceiling):
   - Load is held strictly at the physical boundary.
   - The user is notified with an Equipment Limit notice.
   - Rest interval is dynamically increased ($+45\text{s}$ to $+60\text{s}$) to allow metabolic clearance when mechanical load adjustment is unavailable.
   - For assisted lifts pinned at `maxWeight`, athlete progression shifts into rep accumulation ($R_{min} \to R_{max}$) to build initial capacity.
