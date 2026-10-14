import SwiftUI
import Combine

public struct CalibrationRunnerView: View {
    @ObservedObject var manager: WorkoutSessionManager
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 1 // 1: Set 1, 2: 180s Rest, 3: Set 2, 4: Verdict
    @State private var set1Load: Double
    @State private var set1LoadString: String
    @State private var set1Reps: Int
    @State private var set1RepsString: String
    @State private var set2Reps: Int
    @State private var set2RepsString: String
    @State private var restSecondsRemaining: Int = 180
    @State private var isRestTimerRunning: Bool = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Computed Verdict Results
    @State private var computedE1RM: Double = 0.0
    @State private var computedFI: Double = 0.0
    @State private var computedLoads: [Double] = [0, 0, 0]

    public init(manager: WorkoutSessionManager, exercise: Exercise) {
        self.manager = manager
        self.exercise = exercise
        let defaultLoad = exercise.weight > 0 ? exercise.weight : (exercise.isAssisted ? 50.0 : 50.0)
        let clampedLoad = min(exercise.effectiveMaxWeight, max(exercise.effectiveMinWeight, defaultLoad))
        _set1Load = State(initialValue: clampedLoad)
        _set1LoadString = State(initialValue: String(format: "%.1f", clampedLoad))
        _set1Reps = State(initialValue: exercise.repWindowMax)
        _set1RepsString = State(initialValue: "\(exercise.repWindowMax)")
        _set2Reps = State(initialValue: max(1, exercise.repWindowMin))
        _set2RepsString = State(initialValue: "\(max(1, exercise.repWindowMin))")
    }

    private var targetSet2Load: Double {
        if exercise.isAssisted {
            let maxW = exercise.effectiveMaxWeight
            let candidate = DPOEngine.roundToStep(set1Load * 1.20, step: exercise.microIncrement)
            return min(maxW, max(set1Load + exercise.microIncrement, candidate))
        } else {
            let minW = exercise.effectiveMinWeight
            let maxW = exercise.effectiveMaxWeight
            let candidate = DPOEngine.roundToStep(set1Load * 0.80, step: exercise.microIncrement)
            return min(maxW, max(minW, candidate))
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    headerCard

                    // Step Tracker
                    stepProgressBar

                    // Content for current step
                    switch step {
                    case 1:
                        set1InputCard
                    case 2:
                        restCountdownCard
                    case 3:
                        set2InputCard
                    case 4:
                        verdictCard
                    default:
                        EmptyView()
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(exercise.isAssisted ? "Counterweight Calibration" : "2-Set Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Theme.hapticImpact(.light)
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.emerald)
                }
            }
            .onReceive(timer) { _ in
                guard isRestTimerRunning else { return }
                if restSecondsRemaining > 0 {
                    restSecondsRemaining -= 1
                    if restSecondsRemaining <= 5 {
                        Theme.hapticTick()
                    }
                } else {
                    isRestTimerRunning = false
                    Theme.hapticSuccess()
                    AudioManager.shared.playTimerComplete()
                    step = 3
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text(exercise.name.uppercased())
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(Theme.emerald)
                    if exercise.isAssisted {
                        Text("ASSIST")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.purple)
                            .cornerRadius(4)
                    }
                }
                Spacer()
                Text(exercise.split)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(6)
                    .foregroundColor(Theme.textSecondary)
            }

            Text(exercise.isAssisted
                ? "SPEC-001 §11 Protocol: Assisted counterweight machine. Muscular failure across 2 sets with 180s rest and +20% assistance pin increment. Objectively derives baseline counterweight capacity and Fatigue Index."
                : "SPEC-001 Protocol: Muscular failure (0 RIR) across 2 sets with mandatory 180s rest and 20% load drop. Objectively derives e1RM and Fatigue Index.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var stepProgressBar: some View {
        HStack(spacing: 8) {
            stepIndicator(title: "1. Anchor Set", index: 1)
            stepIndicator(title: "2. 180s Rest", index: 2)
            stepIndicator(title: exercise.isAssisted ? "3. +20% Assist" : "3. 80% Drop", index: 3)
            stepIndicator(title: "4. Verdict", index: 4)
        }
    }

    private func stepIndicator(title: String, index: Int) -> some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(step >= index ? Theme.emerald : Theme.surfaceElevated)
                .frame(height: 4)
            Text(title)
                .font(.system(size: 10, weight: step == index ? .bold : .medium))
                .foregroundColor(step == index ? Theme.textPrimary : Theme.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 1: Anchor Set
    private var set1InputCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Set 1: Anchor Working Load", systemImage: "dumbbell.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.emerald)
                Spacer()
                Text("0 RIR FAILURE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.amber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.amber.opacity(0.15))
                    .cornerRadius(4)
            }

            VStack(spacing: 12) {
                // Load Stepper
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.isAssisted ? "Assistance Pin (\(exercise.unit.uppercased()))" : "Load (\(exercise.unit.uppercased()))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        if exercise.isAssisted {
                            Text("Stack Limit: \(String(format: "%.1f", exercise.effectiveMaxWeight)) \(exercise.unit)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.purple)
                        } else if exercise.minWeight != nil || exercise.maxWeight != nil {
                            let minStr = exercise.minWeight != nil ? "Min: \(String(format: "%.1f", exercise.effectiveMinWeight))" : ""
                            let maxStr = exercise.maxWeight != nil ? "Max: \(String(format: "%.1f", exercise.effectiveMaxWeight))" : ""
                            let sep = (!minStr.isEmpty && !maxStr.isEmpty) ? " • " : ""
                            Text("\(minStr)\(sep)\(maxStr) \(exercise.unit)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.sky)
                        }
                    }
                    Spacer()
                    Button(action: {
                        let floor = exercise.effectiveMinWeight
                        if set1Load > floor + 0.01 {
                            set1Load = max(floor, set1Load - exercise.microIncrement)
                            set1LoadString = String(format: "%.1f", set1Load)
                            Theme.hapticImpact(.light)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.textMuted)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)

                    TextField(String(format: "%.1f", set1Load), text: $set1LoadString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .frame(minWidth: 70)
                        .padding(.vertical, 4)
                        .background(Theme.surfaceCard)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        .onChange(of: set1LoadString) { val in
                            if let num = Double(val.filter { $0.isNumber || $0 == "." }) {
                                set1Load = max(exercise.effectiveMinWeight, min(exercise.effectiveMaxWeight, num))
                            }
                        }
                        .onSubmit {
                            hideKeyboard()
                        }

                    Button(action: {
                        let ceiling = exercise.effectiveMaxWeight
                        if set1Load + exercise.microIncrement <= ceiling + 0.01 {
                            set1Load = min(ceiling, set1Load + exercise.microIncrement)
                            set1LoadString = String(format: "%.1f", set1Load)
                            Theme.hapticImpact(.light)
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.emerald)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }

                Divider().background(Theme.border)

                // Reps Stepper & Keypad
                HStack {
                    Text("Completed Reps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Button(action: {
                        if set1Reps > 1 {
                            set1Reps -= 1
                            set1RepsString = "\(set1Reps)"
                            Theme.hapticImpact(.light)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.textMuted)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)

                    TextField("\(set1Reps)", text: $set1RepsString)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .frame(minWidth: 50)
                        .padding(.vertical, 4)
                        .background(Theme.surfaceCard)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        .onChange(of: set1RepsString) { val in
                            if let num = Int(val.filter { $0.isNumber }) {
                                set1Reps = max(1, num)
                            }
                        }
                        .onSubmit {
                            hideKeyboard()
                        }

                    Button(action: {
                        set1Reps += 1
                        set1RepsString = "\(set1Reps)"
                        Theme.hapticImpact(.light)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.emerald)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(16)
            .background(Theme.surfaceElevated)
            .cornerRadius(12)

            Button(action: {
                Theme.hapticNotification(.success)
                restSecondsRemaining = 180
                isRestTimerRunning = true
                step = 2
            }) {
                HStack {
                    Text("Log Set 1 & Start 180s Rest")
                    Image(systemName: "timer")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.emerald)
                .cornerRadius(12)
            }
        }
        .padding(18)
        .background(Theme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Step 2: Rest Countdown
    private var restCountdownCard: some View {
        VStack(spacing: 20) {
            Text("MANDATORY 180s CALIBRATION REST")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(Theme.sky)
                .tracking(1)

            // Circular Countdown Dial
            ZStack {
                Circle()
                    .stroke(Theme.surfaceElevated, lineWidth: 12)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: CGFloat(restSecondsRemaining) / 180.0)
                    .stroke(
                        LinearGradient(colors: [Theme.emerald, Theme.cyan], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                    .animation(.linear(duration: 1.0), value: restSecondsRemaining)

                VStack(spacing: 2) {
                    Text(formatTime(restSecondsRemaining))
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                    Text("REMAINING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.vertical, 8)

            VStack(spacing: 6) {
                Text("Next Set Preparation:")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Text(exercise.isAssisted
                    ? "Set 2 Assistance: \(String(format: "%.1f", targetSet2Load)) \(exercise.unit.uppercased()) (+20% Assistance)"
                    : "Set 2 Load: \(String(format: "%.1f", targetSet2Load)) \(exercise.unit.uppercased()) (\(targetSet2Load <= exercise.effectiveMinWeight && exercise.effectiveMinWeight > 0 ? "Stack Min Floor" : "-20% Drop"))")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Theme.emerald)
            }

            HStack(spacing: 12) {
                Button(action: {
                    restSecondsRemaining = min(300, restSecondsRemaining + 30)
                    Theme.hapticImpact(.light)
                }) {
                    Text("+30s")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(10)
                }

                Button(action: {
                    isRestTimerRunning = false
                    Theme.hapticImpact(.medium)
                    step = 3
                }) {
                    Text("Skip to Set 2")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Theme.sky)
                        .cornerRadius(10)
                }
            }
        }
        .padding(24)
        .background(Theme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Step 3: Set 2 (Fatigue-Index Probe)
    private var set2InputCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Set 2: Fatigue-Index Probe", systemImage: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.amber)
                Spacer()
                Text(exercise.isAssisted ? "+20% ASSIST PIN" : (targetSet2Load <= exercise.effectiveMinWeight && exercise.effectiveMinWeight > 0 ? "STACK MIN FLOOR" : "80% LOAD DROP"))
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.sky)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.sky.opacity(0.15))
                    .cornerRadius(4)
            }

            VStack(spacing: 12) {
                HStack {
                    Text(exercise.isAssisted ? "Calculated Assistance (+20%)" : "Calculated Load (80%)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(String(format: "%.1f", targetSet2Load)) \(exercise.unit.uppercased())\(exercise.isAssisted ? " Assist" : "")")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Theme.emerald)
                }

                Divider().background(Theme.border)

                HStack {
                    Text("Actual Reps to Failure (0 RIR)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Button(action: {
                        if set2Reps > 1 {
                            set2Reps -= 1
                            set2RepsString = "\(set2Reps)"
                            Theme.hapticImpact(.light)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.textMuted)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)

                    TextField("\(set2Reps)", text: $set2RepsString)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .frame(minWidth: 50)
                        .padding(.vertical, 4)
                        .background(Theme.surfaceCard)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        .onChange(of: set2RepsString) { val in
                            if let num = Int(val.filter { $0.isNumber }) {
                                set2Reps = max(1, num)
                            }
                        }
                        .onSubmit {
                            hideKeyboard()
                        }

                    Button(action: {
                        set2Reps += 1
                        set2RepsString = "\(set2Reps)"
                        Theme.hapticImpact(.light)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.emerald)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(16)
            .background(Theme.surfaceElevated)
            .cornerRadius(12)

            Button(action: {
                solveCalibrationVerdict()
                step = 4
                Theme.hapticSuccess()
                AudioManager.shared.playFanfare()
            }) {
                HStack {
                    Text("Compute DPO Calibration")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.emerald)
                .cornerRadius(12)
            }
        }
        .padding(18)
        .background(Theme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Step 4: Verdict
    private var verdictCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Theme.emerald)
                Text(exercise.isAssisted ? "COUNTERWEIGHT DERIVED" : "CALIBRATION DERIVED")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                    .tracking(1)
            }

            VStack(spacing: 12) {
                metricRow(title: "Calculated e1RM Capacity", value: String(format: "%.1f %@", computedE1RM, exercise.unit.uppercased()), highlight: Theme.purple)
                metricRow(title: "Fatigue Index (FI)", value: String(format: "%.3f", computedFI), highlight: Theme.sky)
                metricRow(
                    title: exercise.isAssisted ? "A1 Anchor Pin (Set 1 - Hardest)" : "W1 Anchor (Set 1)",
                    value: String(format: "%.1f %@%@", computedLoads[0], exercise.unit.uppercased(), exercise.isAssisted ? " Assist" : ""),
                    highlight: Theme.emerald
                )
                metricRow(
                    title: exercise.isAssisted ? "A2 Intermediate Pin (Set 2)" : "W2 Intermediate (Set 2)",
                    value: String(format: "%.1f %@%@", computedLoads[1], exercise.unit.uppercased(), exercise.isAssisted ? " Assist" : ""),
                    highlight: Theme.cyan
                )
                metricRow(
                    title: exercise.isAssisted ? "A3 Base Hypertrophy Pin (Set 3)" : "W3 Base Overload (Set 3)",
                    value: String(format: "%.1f %@%@", computedLoads[2], exercise.unit.uppercased(), exercise.isAssisted ? " Assist" : ""),
                    highlight: Theme.amber
                )
            }
            .padding(16)
            .background(Theme.surfaceElevated)
            .cornerRadius(12)

            Button(action: {
                manager.applyCalibration(
                    exerciseId: exercise.id,
                    e1RM: computedE1RM,
                    fatigueIndex: computedFI,
                    loads: computedLoads,
                    set1Load: set1Load,
                    set1Reps: set1Reps,
                    set2Load: targetSet2Load,
                    set2Reps: set2Reps
                )
                dismiss()
            }) {
                Text("Commit Calibration to Exercise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.emerald)
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Theme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.emerald, lineWidth: 1.5))
    }

    private func metricRow(title: String, value: String, highlight: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(highlight)
        }
    }

    // MARK: - Logic
    private func solveCalibrationVerdict() {
        let result = DPOEngine.executeCalibration(
            set1Load: set1Load,
            set1Reps: set1Reps,
            set2Load: targetSet2Load,
            set2Reps: set2Reps,
            microIncrement: exercise.microIncrement,
            isAssisted: exercise.isAssisted,
            minWeight: exercise.minWeight,
            maxWeight: exercise.maxWeight,
            unit: exercise.unit
        )
        computedE1RM = result.e1RM
        computedFI = result.fatigueIndex
        computedLoads = result.loads
    }

    private func formatTime(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }
}
