---
name: dpo-hypertrophy-engine
description: >-
  Provides operational runbooks, architectural specifications, mathematical invariants,
  and verification procedures for the iPhone Fitness App and its Dynamic Progressive Overload (DPO)
  engine. Use this skill when modifying, debugging, or verifying exercise models, counterweight mechanics,
  pin-loaded weight stack boundaries, calibration protocols, dynamic rest periods, Live Activities,
  or JSON backup/sync workflows.
---

# Dynamic Progressive Overload (DPO) Engine Skill

This skill is the authoritative developer runbook and system architecture guide for the **iPhone Fitness App** and its core **Dynamic Progressive Overload (DPO) Hypertrophy Engine** (`SPEC-001`).

---

## 1. System Overview & Technology Stack

* **Platform**: iOS 17.0+ (Universal iPhone, optimized for iPhone 16 Pro Max).
* **Frameworks**: SwiftUI, Swift Charts, ActivityKit, AppIntents, AVFoundation, AudioToolbox.
* **Architecture**: Clean Modular Architecture with a shared Swift Package (`SharedWorkoutModels`) consumed by both the primary iOS Application target (`App`) and the ActivityKit Widget Extension (`WorkoutWidgets`).
* **Data Storage**: Local JSON serialization with App Group container (`group.com.fitness.dpo`) support for widget synchronization and full-state export/import backup.

---

## 2. Mathematical Invariants & Core Rules (SPEC-001)

### 2.1 Standard Resistance Lifts (Barbell, Dumbbell, Cable, Machine)
For normal exercises, load strictly cascades downwards across the sets:
```text
W_1 >= W_2 >= W_3
W_2 >= Floor(W_2) = roundToStep(0.80 * W_1, microIncrement)
W_3 >= Floor(W_3) = roundToStep(0.60 * W_1, microIncrement)
```
* **Anchor Load ($W_1$)**: Prescribed primary overload set (Set 1).
* **Set 2 Floor**: Never drops below 80% of Set 1 load.
* **Set 3 Floor**: Never drops below 60% of Set 1 load.
* **Step Rounding**:
  $$\text{roundToStep}(X, S) = \text{round}\left(\frac{X}{S}\right) \times S$$
* **Baechle Estimated 1RM (e1RM)**:
  $$\text{e1RM} = W \times \left(1 + \frac{R}{30}\right)$$

### 2.2 Pin-Loaded & Cable Stack Boundaries (`minWeight`, `maxWeight`)
For pin-loaded machines and cable stacks:
* Physical equipment limits prevent loads lower than the lowest plate (`minWeight`) or higher than the top of the stack (`maxWeight`).
* **Effective Stack Clamping**:
  $$W_{\text{effective}} = \min(maxWeight, \max(minWeight, W))$$
* When Set 2 ($0.80 \times W_1$) or Set 3 ($0.60 \times W_1$) drops to `minWeight`, the UI displays a `(Stack Min Floor)` indicator, preventing below-stack load prescriptions.
* Deloads from missed reps are clamped at `effectiveMinWeight`.
* Progression advancements are clamped at `effectiveMaxWeight`.

### 2.3 Counterweight / Assisted Exercises (`isCounterweight = true`)
For assisted movements (e.g. Assisted Pull-Ups, Assisted Dips):
* **Inverted Mechanics**: The weight stack provides counter-assistance. A *higher* assistance load makes the exercise easier; a *lower* assistance load makes the exercise harder.
* **Progression Advance**: Reaching or exceeding target reps advances the lifter by **decreasing** assistance:
  $$A_{\text{next}} = \max(\text{minAssistance}, A_1 - \text{microIncrement})$$
* **Drop Sets**: If fatigue requires a drop in difficulty, assistance is **increased** (up to `maxWeight` / `maxAssistance`):
  $$A_2 = \min(\text{maxAssistance}, \text{roundToStep}(A_1 \times 1.20, \text{microIncrement}))$$
* **Missed Reps**: Deloading an assisted exercise increases assistance to reduce the net user load.

### 2.4 Normalized Fatigue Index ($FI$)
Measured in calibration sequences:
$$FI = \text{clamp}\left(1 - \frac{R_{2,\text{actual}}}{R_{2,\text{expected}}}, \quad 0.0, \quad 1.0\right)$$
Where $R_{2,\text{expected}} = 30 \times \left(\frac{\text{e1RM}}{W_2} - 1\right)$.

### 2.5 Consolidation Gates for Set 1 Promotion
Set 1 load ($W_1$) cannot advance unless the following consolidation gates pass:
* **3-Set Mode**:
  1. $W_2 \ge 0.85 \times W_1$ (Set 2 load consolidated)
  2. $W_3 \ge 0.65 \times W_1$ (Set 3 load consolidated)
  3. $R_1 \ge \text{targetRepsMax}$
* **2-Set Mode**:
  1. $W_2 \ge 0.85 \times W_1$
  2. $R_1 \ge \text{targetRepsMax}$

### 2.6 Consecutive Floor Breach & Mode Demotion
If Set 3 hits the 60% floor boundary and fails to complete minimum reps for 2 consecutive workouts, the exercise drops from **3-Set mode to 2-Set mode** to prevent overtraining.

### 2.7 Set 3 Re-Entry Gate
Re-entering 3-Set mode requires passing all 3 criteria across 2 consecutive sessions:
1. $W_2 / W_1 \ge 0.85$ in both sessions.
2. Intra-session rep drop between Set 1 and Set 2 $\le 2$ reps in both sessions.
3. Set 2 reps $\ge \text{targetRepsMax}$ in at least one of the two sessions.
Initial Set 3 re-entry load is set conservatively at $65\%$ of $W_1$.

---

## 3. Project Directory Map

```text
iphone-fitness-app/
├── DPO PRODSPEC.MD                                       # Authoritative SPEC-001 specification
├── Skill.md                                              # Root developer skill copy
├── .agents/skills/dpo-hypertrophy-engine/
│   ├── SKILL.md                                          # Workspace discoverable skill entry point
│   └── scripts/
│       └── verify_engine.sh                              # Standalone verification runner
├── Tests/
│   └── DPOTestSuite.swift                                # 71-test mathematical test harness
└── ios/App/
    ├── App.xcodeproj                                     # Xcode project configuration
    ├── App/
    │   ├── SceneDelegate.swift                           # SwiftUI WindowGroup mounting
    │   └── Info.plist                                    # Dynamic Island & background audio entitlements
    ├── SharedWorkoutModels/Sources/                      # Core Shared Framework
    │   ├── DPOEngine.swift                               # Mathematical calculation engine
    │   ├── Exercise.swift                                # Data models & stack boundaries
    │   ├── WorkoutStore.swift                            # Persistence & JSON sync
    │   ├── WorkoutSessionManager.swift                   # Active session state machine & timer
    │   ├── LiveActivityManager.swift                     # ActivityKit integration
    │   ├── AudioManager.swift                            # Sensory feedback sound synthesis
    │   └── Views/
    │       ├── MainTabView.swift                         # Tab bar navigation
    │       ├── ExerciseHubView.swift                     # Primary exercise manager
    │       ├── AddEditExerciseSheet.swift                # Exercise configuration (stack limits, unit)
    │       ├── WorkingChamberView.swift                  # Active set logging chamber
    │       ├── CalibrationHubView.swift                  # Calibration directory
    │       ├── CalibrationRunnerView.swift               # 3-step calibration flow
    │       ├── OverloadProjectionsView.swift             # Swift Charts overload curve viewer
    │       ├── DataBackupSheet.swift                     # Full state JSON export/import
    │       └── DPOHandbookView.swift                     # In-app reference manual
    └── WorkoutWidgets/
        └── WorkoutWidgets.swift                          # Dynamic Island & Lock Screen Live Activity
```

---

## 4. Workflows & Runbooks

### Runbook A: Adding or Updating an Exercise
1. Open `AddEditExerciseSheet.swift`.
2. Select Category (`Heavy Compound`, `Machine Compound`, or `Isolation`).
3. Select Equipment Type (`Barbell`, `Dumbbell`, `Cable Stack`, `Machine Lever`, `Bodyweight Loaded`).
4. Configure Unit (`KG` or `LBS`) and micro-increment step (e.g. 1.25, 2.5, 5.0).
5. If pin-loaded or cable machine:
   - Toggle **Enable Stack Limits**.
   - Set **Lowest Weight Plate** (`minWeight`).
   - Set **Heaviest Weight Plate** (`maxWeight`).
6. If counterweight / assisted:
   - Toggle **Assisted Exercise**.
   - Set **Maximum Assistance** limit.

### Runbook B: Verifying DPO Math & Invariants
Run the verification script anytime changes are made to `DPOEngine.swift` or `Exercise.swift`:
```bash
.agents/skills/dpo-hypertrophy-engine/scripts/verify_engine.sh
```
Or run the individual components:
```bash
# 1. Run the 71-case mathematical verification harness
swiftc Tests/DPOTestSuite.swift \
  ios/App/SharedWorkoutModels/Sources/DPOEngine.swift \
  ios/App/SharedWorkoutModels/Sources/Exercise.swift \
  -o /tmp/dpo_test_runner && /tmp/dpo_test_runner

# 2. Verify compilation for iOS Simulator
xcodebuild \
  -project ios/App/App.xcodeproj \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -quiet
```

### Runbook C: Exporting & Importing Workout Data
1. Navigate to **Handbook & History** $\to$ **Backup & Cloud Sync** in the iOS app.
2. **Export**: Generates a unified JSON payload containing:
   - All custom and library exercises with calibration states, min/max stack limits, and e1RM.
   - Complete historical workout logs, completed set reps, loads, and timestamps.
3. **Import**: Parses and validates incoming JSON payload, merges or replaces exercises with atomic disk persistence.

### Runbook D: Building and Packaging the iOS IPA
Generate an installable `.ipa` bundle (including the embedded Dynamic Island Live Activity extension):
```bash
.agents/skills/dpo-hypertrophy-engine/scripts/build_ipa.sh
```
This runs the mathematical test suite, compiles a Release archive for generic iOS devices (`arm64`), ad-hoc signs all Mach-O binaries and app extensions, and produces `FitnessApp.ipa` directly in the project root.

---

## 5. Verification Checklist

Before committing any modifications to the repository, ensure:
- [x] All 71 tests in `DPOTestSuite.swift` pass with 100% compliance.
- [x] iOS Simulator build completes with 0 errors (`xcodebuild ... build`).
- [x] Invariants $W_1 \ge W_2 \ge W_3$ and floor limits are strictly clamped against `minWeight` and `maxWeight`.
- [x] Counterweight assistance inversion is preserved.
- [x] Live Activity attributes serialize cleanly without breaking App Groups container storage.
