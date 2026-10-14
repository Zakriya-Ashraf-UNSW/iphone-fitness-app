import SwiftUI

public struct WorkingChamberView: View {
    @ObservedObject var manager: WorkoutSessionManager
    let setNumber: Int

    @State private var load: Double = 0.0
    @State private var loadText: String = "0.0"
    @State private var isAdjustingLoad: Bool = false
    @State private var showCustomRepLogger: Bool = false
    @State private var reps: Int = 10
    @State private var repsText: String = "10"

    public init(manager: WorkoutSessionManager, setNumber: Int) {
        self.manager = manager
        self.setNumber = setNumber
    }

    private var currentLoad: Double {
        guard let ex = manager.currentExercise else { return 0 }
        let idx = setNumber - 1
        return ex.loads.indices.contains(idx) ? ex.loads[idx] : ex.weight
    }

    private var displayLoad: Double {
        isAdjustingLoad ? load : currentLoad
    }

    private var outcome: String? {
        switch setNumber {
        case 1: return manager.s1Outcome
        case 2: return manager.s2Outcome
        default: return manager.s3Outcome
        }
    }

    private var verdict: String? {
        switch setNumber {
        case 1: return manager.s1Verdict
        case 2: return manager.s2Verdict
        default: return manager.s3Verdict
        }
    }

    private var setTitle: String {
        guard let ex = manager.currentExercise, ex.isAssisted else {
            switch setNumber {
            case 1: return "SET 1: ANCHOR DRIVER"
            case 2: return "SET 2: INTERMEDIATE SET"
            default: return "SET 3: BASE HYPERTROPHY"
            }
        }
        switch setNumber {
        case 1: return "SET 1: ANCHOR ASSISTANCE (HARDEST)"
        case 2: return "SET 2: INTERMEDIATE ASSISTANCE (+20%)"
        default: return "SET 3: BASE ASSISTANCE (+40%)"
        }
    }

    private var setAccentColor: Color {
        switch setNumber {
        case 1: return Theme.emerald
        case 2: return Theme.sky
        default: return Theme.purple
        }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(setTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(setAccentColor)
                        .tracking(1.0)
                    Text("Working Set \(setNumber) of \(manager.currentExercise?.activeSetsCount ?? 3)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
            }

            // Prescribed Load & Target Reps Card
            if let ex = manager.currentExercise {
                HStack(spacing: 16) {
                    // Load Column
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(ex.isAssisted ? "ASSISTANCE PIN" : "PRESCRIBED LOAD")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.textMuted)
                                .tracking(0.5)
                            if ex.isAssisted {
                                Text("🤝")
                                    .font(.system(size: 10))
                            }
                        }
                        Text(ex.isAssisted
                            ? String(format: "%.1f %@ Assist", displayLoad, ex.unit.uppercased())
                            : String(format: "%.1f %@", displayLoad, ex.unit.uppercased()))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)

                        Button(action: {
                            if !isAdjustingLoad {
                                load = currentLoad
                                loadText = String(format: "%.1f", currentLoad)
                            }
                            isAdjustingLoad.toggle()
                            Theme.hapticImpact(.light)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: isAdjustingLoad ? "chevron.up" : "pencil")
                                    .font(.system(size: 9))
                                Text(isAdjustingLoad ? "Done Adjusting" : "Adjust Load")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(Theme.cyan)
                        }
                        .buttonStyle(.borderless)
                    }

                    Divider()
                        .frame(height: 40)
                        .background(Theme.border)

                    // Target Window Column
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TARGET WINDOW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                            .tracking(0.5)
                        Text("\(ex.repWindowMin)–\(ex.repWindowMax) reps")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("0 RIR Failure")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.amber)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Theme.surfaceCard)
                .cornerRadius(12)

                // Inline Load Adjuster (Keypad + Stepper with Done button)
                if isAdjustingLoad {
                    loadAdjusterBox(ex: ex)
                }

                // PRIMARY 1-TAP TRIAGE BUTTONS (Front and Center)
                triageSection(ex: ex)

                // Optional Rep Logging Toggle & Inline Logger
                optionalRepLoggingSection(ex: ex)
            }

            // Verdict Box (When logged)
            if let v = verdict {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(setAccentColor)
                        .font(.system(size: 16))
                    Text(v)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(nil)
                    Spacer()
                }
                .padding(14)
                .background(setAccentColor.opacity(0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(setAccentColor.opacity(0.3), lineWidth: 1)
                )
            }

            // Advance Navigation Button
            if outcome != nil {
                if setNumber == 1 {
                    Button(action: { manager.goToSet(2) }) {
                        HStack {
                            Spacer()
                            Text("Next: Set 2 (Intermediate) →")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(Theme.sky)
                        .cornerRadius(12)
                    }
                } else if setNumber == 2 {
                    if (manager.currentExercise?.activeSetsCount ?? 3) > 2 {
                        Button(action: { manager.goToSet(3) }) {
                            HStack {
                                Spacer()
                                Text("Next: Set 3 (Base) →")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(Theme.purple)
                            .cornerRadius(12)
                        }
                    } else {
                        finishButton
                    }
                } else {
                    finishButton
                }
            }
        }
        .padding(18)
        .background(Theme.surfaceElevated)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.border, lineWidth: 1)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.emerald)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            syncInitialState(for: setNumber)
        }
        .onChange(of: setNumber) { newSet in
            syncInitialState(for: newSet)
        }
    }

    private func syncInitialState(for targetSet: Int? = nil) {
        guard let ex = manager.currentExercise else { return }
        let currentSet = targetSet ?? setNumber
        let idx = currentSet - 1
        let currentL = ex.loads.indices.contains(idx) ? ex.loads[idx] : ex.weight
        load = currentL
        loadText = String(format: "%.1f", currentL)

        if manager.loggedReps.indices.contains(idx) && manager.loggedReps[idx] > 0 {
            reps = manager.loggedReps[idx]
        } else {
            reps = ex.repWindowMax
        }
        repsText = "\(reps)"
        isAdjustingLoad = false
        showCustomRepLogger = false
    }

    // MARK: - 1-Tap Triage Section

    private func triageSection(ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("1-TAP FAILURE TRIAGE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.textMuted)
                    .tracking(0.8)
                Spacer()
                if let oc = outcome {
                    Text("LOGGED: \(outcomePillLabel(oc, ex: ex))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(outcomeColor(oc))
                }
            }

            HStack(spacing: 8) {
                triageButton(
                    title: "< \(ex.repWindowMin) Missed",
                    subtitle: "Deload/Hold",
                    color: Theme.crimson,
                    isSelected: outcome == "missed",
                    action: { logOutcome("missed") }
                )
                triageButton(
                    title: "\(ex.repWindowMin)–\(ex.repWindowMax) Target",
                    subtitle: "Optimal",
                    color: Theme.emerald,
                    isSelected: outcome == "target",
                    action: { logOutcome("target") }
                )
                triageButton(
                    title: "\(ex.repWindowMax + 1)+ Overload",
                    subtitle: "+Progress",
                    color: Theme.purple,
                    isSelected: outcome == "overload",
                    action: { logOutcome("overload") }
                )
            }
        }
    }

    private func triageButton(title: String, subtitle: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            Theme.hapticImpact(.medium)
            action()
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .black : Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .black.opacity(0.8) : Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(isSelected ? color : Theme.surfaceCard)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func logOutcome(_ o: String) {
        let customL = isAdjustingLoad ? load : nil
        switch setNumber {
        case 1: manager.logSet1(outcome: o, customReps: nil, customLoad: customL)
        case 2: manager.logSet2(outcome: o, customReps: nil, customLoad: customL)
        default: manager.logSet3(outcome: o, customReps: nil, customLoad: customL)
        }
    }

    // MARK: - Optional Exact Reps Section

    private func optionalRepLoggingSection(ex: Exercise) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCustomRepLogger.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showCustomRepLogger ? "chevron.up.circle.fill" : "slider.horizontal.3")
                            .font(.system(size: 11))
                        Text(showCustomRepLogger ? "Hide Exact Rep Logger" : "Log Exact Reps (Optional)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    manager.showCustomRepsSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10))
                        Text("Full Modal")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Theme.cyan)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)

            if showCustomRepLogger {
                repLoggerCard(ex: ex)
            }
        }
    }

    private func repLoggerCard(ex: Exercise) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("EXACT REPS COMPLETED")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.textMuted)
                    .tracking(0.8)

                Spacer()

                // Dynamic Outcome Pill
                outcomeStatusBadge(ex: ex)
            }

            // Stepper and Keypad Reps Display
            HStack(spacing: 16) {
                // Minus Button
                Button(action: {
                    if reps > 0 {
                        reps -= 1
                        repsText = "\(reps)"
                        Theme.hapticImpact(.light)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(reps > 0 ? Theme.crimson : Theme.textMuted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(reps <= 0)

                // Keypad Number Input
                VStack(spacing: 2) {
                    TextField("\(reps)", text: $repsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .frame(minWidth: 80)
                        .frame(height: 42)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.borderHighlight, lineWidth: 1)
                        )
                        .onChange(of: repsText) { newVal in
                            if let parsed = Int(newVal.filter { $0.isNumber }) {
                                reps = max(0, parsed)
                            }
                        }
                        .onSubmit {
                            hideKeyboard()
                        }

                    Text("Tap to type on keypad")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textMuted)
                }

                // Plus Button
                Button(action: {
                    reps += 1
                    repsText = "\(reps)"
                    Theme.hapticImpact(.light)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.emerald)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 2)

            // Quick Preset Chips
            HStack(spacing: 6) {
                quickChip(label: "Missed (\(max(0, ex.repWindowMin - 1)))", targetReps: max(0, ex.repWindowMin - 1), color: Theme.crimson)
                quickChip(label: "Min (\(ex.repWindowMin))", targetReps: ex.repWindowMin, color: Theme.emerald)
                quickChip(label: "Max (\(ex.repWindowMax))", targetReps: ex.repWindowMax, color: Theme.emerald)
                quickChip(label: "Overload (\(ex.repWindowMax + 1))", targetReps: ex.repWindowMax + 1, color: Theme.purple)
            }

            // Commit Custom Reps Button
            Button(action: {
                hideKeyboard()
                logWithCurrentValues()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text(outcome == nil
                         ? "Commit \(reps) Reps & Start Rest →"
                         : "Update Set Log (\(reps) Reps)")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(setAccentColor)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.surfaceCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private var derivedOutcome: String {
        guard let ex = manager.currentExercise else { return "target" }
        if reps < ex.repWindowMin {
            return "missed"
        } else if reps > ex.repWindowMax {
            return "overload"
        } else {
            return "target"
        }
    }

    private func outcomeStatusBadge(ex: Exercise) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(outcomeColor(derivedOutcome))
                .frame(width: 6, height: 6)

            Text(outcomePillLabel(derivedOutcome, ex: ex))
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(outcomeColor(derivedOutcome))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(outcomeColor(derivedOutcome).opacity(0.12))
        .cornerRadius(6)
    }

    private func quickChip(label: String, targetReps: Int, color: Color) -> some View {
        Button(action: {
            reps = targetReps
            repsText = "\(targetReps)"
            Theme.hapticImpact(.light)
        }) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(reps == targetReps ? .black : Theme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(reps == targetReps ? color : Theme.surfaceElevated)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(reps == targetReps ? Color.clear : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load Adjuster Box

    private func loadAdjusterBox(ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ex.isAssisted ? "OVERRIDE ASSISTANCE PIN FOR THIS SET" : "OVERRIDE WORKING LOAD FOR THIS SET")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Theme.cyan)
                Spacer()
                Button("Done") {
                    hideKeyboard()
                    isAdjustingLoad = false
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.emerald)
            }

            HStack(spacing: 12) {
                // Minus load
                Button(action: {
                    let floor = ex.effectiveMinWeight
                    if load - ex.microIncrement >= floor - 0.01 {
                        load = max(floor, load - ex.microIncrement)
                        loadText = String(format: "%.1f", load)
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

                // Keypad Load TextField
                TextField(String(format: "%.1f", load), text: $loadText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .frame(minWidth: 80)
                    .frame(height: 38)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cyan.opacity(0.5), lineWidth: 1))
                    .onChange(of: loadText) { newVal in
                        if let parsed = Double(newVal.filter { $0.isNumber || $0 == "." }) {
                            load = max(ex.effectiveMinWeight, min(ex.effectiveMaxWeight, parsed))
                        }
                    }
                    .onSubmit {
                        hideKeyboard()
                    }

                Text(ex.unit.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)

                // Plus load
                Button(action: {
                    let ceil = ex.effectiveMaxWeight
                    if load + ex.microIncrement <= ceil + 0.01 {
                        load = min(ceil, load + ex.microIncrement)
                        loadText = String(format: "%.1f", load)
                        Theme.hapticImpact(.light)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Theme.cyan)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

                Spacer()
            }
        }
        .padding(12)
        .background(Theme.surfaceElevated)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cyan.opacity(0.3), lineWidth: 1))
    }

    private func outcomeColor(_ o: String) -> Color {
        switch o {
        case "overload": return Theme.purple
        case "target": return Theme.emerald
        default: return Theme.crimson
        }
    }

    private func outcomePillLabel(_ o: String, ex: Exercise) -> String {
        switch o {
        case "overload": return "\(ex.repWindowMax + 1)+ OVERLOAD"
        case "target": return "\(ex.repWindowMin)–\(ex.repWindowMax) TARGET"
        default: return "< \(ex.repWindowMin) MISSED"
        }
    }

    private func logWithCurrentValues() {
        let oc = derivedOutcome
        switch setNumber {
        case 1:
            manager.logSet1(outcome: oc, customReps: reps, customLoad: isAdjustingLoad ? load : nil)
        case 2:
            manager.logSet2(outcome: oc, customReps: reps, customLoad: isAdjustingLoad ? load : nil)
        default:
            manager.logSet3(outcome: oc, customReps: reps, customLoad: isAdjustingLoad ? load : nil)
        }
    }

    private var finishButton: some View {
        Button(action: { manager.commitCurrentExercise() }) {
            HStack {
                Spacer()
                Text("Save, Log & Next Lift →")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(Theme.emerald)
            .cornerRadius(12)
        }
    }
}
