import SwiftUI

public struct AddEditExerciseSheet: View {
    @ObservedObject var manager: WorkoutSessionManager
    let exerciseToEdit: Exercise?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var split: WorkoutSplit = .push
    @State private var muscleGroup: String = "Chest"
    @State private var category: ExerciseCategory = .heavyCompound
    @State private var equipment: EquipmentType = .barbell
    @State private var unit: String = "kg"
    @State private var microIncrement: Double = 1.25
    @State private var repWindowMin: Int = 8
    @State private var repWindowMax: Int = 12
    @State private var anchorWeight: Double = 60.0
    @State private var isAssisted: Bool = false
    @State private var hasStackLimits: Bool = false
    @State private var minWeight: Double = 5.0
    @State private var maxWeight: Double = 100.0
    @State private var showDeleteConfirm: Bool = false

    // Keypad Support String States
    @State private var anchorWeightString: String = "60.0"
    @State private var minWeightString: String = "5.0"
    @State private var maxWeightString: String = "100.0"
    @State private var repMinString: String = "8"
    @State private var repMaxString: String = "12"

    // Calibration Runner Sheet
    @State private var showCalibrationRunner: Bool = false

    private var isEditing: Bool { exerciseToEdit != nil }

    public init(manager: WorkoutSessionManager, exerciseToEdit: Exercise? = nil) {
        self.manager = manager
        self.exerciseToEdit = exerciseToEdit
    }

    private var liveExercise: Exercise? {
        guard let ex = exerciseToEdit else { return nil }
        return manager.exercises.first(where: { $0.id == ex.id }) ?? ex
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Basic Information
                Section(header: Text("EXERCISE IDENTITY").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.emerald)) {
                    TextField("Exercise Name (e.g. Incline Bench)", text: $name)
                        .foregroundColor(Theme.textPrimary)

                    Picker("Routine Split", selection: $split) {
                        ForEach(WorkoutSplit.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }

                    TextField("Target Muscle Group", text: $muscleGroup)
                        .foregroundColor(Theme.textPrimary)
                }
                .listRowBackground(Theme.surfaceElevated)

                // Calibration & Recalibration Section (When in Edit Exercise Mode)
                if isEditing, let ex = liveExercise {
                    calibrationActionSection(ex: ex)
                        .listRowBackground(Theme.surfaceElevated)
                }

                // Section 2: Equipment & Category
                Section(header: Text("SPEC-001 BIOMECHANICS").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.emerald)) {
                    Picker("Exercise Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }

                    Picker("Equipment Type", selection: $equipment) {
                        ForEach(EquipmentType.allCases) { eq in
                            Text(eq.displayName).tag(eq)
                        }
                    }
                    .onChange(of: equipment) { newEquipment in
                        applyEquipmentDefaults(newEquipment)
                    }

                    Picker("Unit", selection: $unit) {
                        Text("KG (Kilograms)").tag("kg")
                        Text("LBS (Pounds)").tag("lbs")
                    }
                    .onChange(of: unit) { _ in
                        applyEquipmentDefaults(equipment)
                    }

                    HStack {
                        Text("Micro-Increment Step")
                        Spacer()
                        Stepper("\(String(format: "%.2f", microIncrement)) \(unit)", value: $microIncrement, in: 0.25...10.0, step: 0.25)
                    }

                    // Counterweight / Assisted Exercise Toggle
                    Toggle(isOn: $isAssisted) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Counterweight / Assisted Lift")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            Text("Selectorized pin assistance (e.g. Assisted Pull-Up or Dip). Getting stronger decreases pin weight.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.purple)

                    if isAssisted {
                        // Lowest Assistance Floor
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lowest Assistance Floor")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Machine minimum before unassisted bodyweight")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            keypadStepper(
                                value: $minWeight,
                                textValue: $minWeightString,
                                step: microIncrement,
                                floor: 0.0,
                                ceil: maxWeight - microIncrement,
                                unit: unit
                            )
                        }

                        // Machine Assistance Ceiling
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Machine Assistance Ceiling")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Maximum counterweight plate on machine")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            keypadStepper(
                                value: $maxWeight,
                                textValue: $maxWeightString,
                                step: microIncrement,
                                floor: minWeight + microIncrement,
                                ceil: 1200.0,
                                unit: unit
                            )
                        }
                    } else {
                        // Pin-Loaded / Machine Weight Stack Limits
                        Toggle(isOn: $hasStackLimits) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weight Stack Limits (Min / Max)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Set physical stack bounds (prevents DPO from prescribing loads lower than lowest plate)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .tint(Theme.emerald)

                        if hasStackLimits {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lowest Weight Plate (Stack Min)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Starting plate / lowest selectable weight on machine")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                keypadStepper(
                                    value: $minWeight,
                                    textValue: $minWeightString,
                                    step: microIncrement,
                                    floor: 0.0,
                                    ceil: maxWeight - microIncrement,
                                    unit: unit
                                )
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Heaviest Weight Plate (Stack Max)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Maximum pin plate available on machine stack")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                keypadStepper(
                                    value: $maxWeight,
                                    textValue: $maxWeightString,
                                    step: microIncrement,
                                    floor: minWeight + microIncrement,
                                    ceil: 1500.0,
                                    unit: unit
                                )
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surfaceElevated)

                // Section 3: Rep Target Window & Working Load
                Section(header: Text("TARGET CADENCE & LOADS").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.emerald)) {
                    HStack {
                        Text("Rep Window Min (R_min)")
                        Spacer()
                        repKeypadStepper(
                            value: $repWindowMin,
                            textValue: $repMinString,
                            floor: 3,
                            ceil: repWindowMax
                        )
                    }

                    HStack {
                        Text("Rep Window Max (R_max)")
                        Spacer()
                        repKeypadStepper(
                            value: $repWindowMax,
                            textValue: $repMaxString,
                            floor: repWindowMin,
                            ceil: 30
                        )
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isAssisted ? "Anchor Assistance Pin (Set 1)" : "Anchor Working Load (W1)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            if isAssisted {
                                Text("Lowest counterweight pin (hardest set)")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        keypadStepper(
                            value: $anchorWeight,
                            textValue: $anchorWeightString,
                            step: microIncrement,
                            floor: isAssisted ? minWeight : 0.0,
                            ceil: isAssisted ? maxWeight : 1500.0,
                            unit: unit
                        )
                    }
                }
                .listRowBackground(Theme.surfaceElevated)

                // Section 4: Invariant Cascades Preview
                Section(header: Text(isAssisted ? "ASSISTED COUNTERWEIGHT INVARIANTS" : "STARTING INVARIANT CASCADES").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.sky)) {
                    if isAssisted {
                        let a1 = min(maxWeight, max(minWeight, anchorWeight))
                        let a2 = min(maxWeight, max(a1 + microIncrement, DPOEngine.roundToStep(a1 * 1.20, step: microIncrement)))
                        let a3 = min(maxWeight, max(a2 + microIncrement, DPOEngine.roundToStep(a1 * 1.40, step: microIncrement)))

                        HStack {
                            Text("A1 Anchor (Lowest Pin / Hardest)")
                            Spacer()
                            Text("\(String(format: "%.1f", a1)) \(unit) Assist").bold().foregroundColor(Theme.emerald)
                        }
                        HStack {
                            Text("A2 Intermediate (+20% Help)")
                            Spacer()
                            Text("\(String(format: "%.1f", a2)) \(unit) Assist").bold().foregroundColor(Theme.cyan)
                        }
                        HStack {
                            Text("A3 Base Overload (+40% Help)")
                            Spacer()
                            Text("\(String(format: "%.1f", a3)) \(unit) Assist").bold().foregroundColor(Theme.amber)
                        }
                    } else {
                        let minW = hasStackLimits ? minWeight : 0.0
                        let maxW = hasStackLimits ? maxWeight : Double.infinity
                        let w1 = min(maxW, max(minW, anchorWeight))
                        let w2 = min(maxW, max(minW, DPOEngine.roundToStep(w1 * 0.80, step: microIncrement)))
                        let w3 = min(maxW, max(minW, DPOEngine.roundToStep(w1 * 0.60, step: microIncrement)))

                        HStack {
                            Text("W1 Anchor")
                            Spacer()
                            Text("\(String(format: "%.1f", w1)) \(unit)").bold().foregroundColor(Theme.emerald)
                        }
                        HStack {
                            Text(hasStackLimits && w2 <= minW && minW > 0 ? "W2 Intermediate (Stack Min Floor)" : "W2 Intermediate (≥ 80%)")
                            Spacer()
                            Text("\(String(format: "%.1f", w2)) \(unit)").bold().foregroundColor(Theme.cyan)
                        }
                        HStack {
                            Text(hasStackLimits && w3 <= minW && minW > 0 ? "W3 Base (Stack Min Floor)" : "W3 Base (≥ 60%)")
                            Spacer()
                            Text("\(String(format: "%.1f", w3)) \(unit)").bold().foregroundColor(Theme.amber)
                        }
                    }
                }
                .listRowBackground(Theme.surfaceElevated)

                // Delete Button (if editing)
                if isEditing {
                    Section {
                        Button(role: .destructive, action: {
                            showDeleteConfirm = true
                        }) {
                            HStack {
                                Spacer()
                                Label("Delete Lift", systemImage: "trash.fill")
                                    .foregroundColor(Theme.crimson)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(Theme.surfaceElevated)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Lift" : "New Lift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExercise() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.textMuted : Theme.emerald)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                        syncStringsAfterKeyboardDismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.emerald)
                }
            }
            .confirmationDialog("Delete \(name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let ex = exerciseToEdit {
                        manager.deleteExercise(id: ex.id)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes the lift from your routine library.")
            }
            .sheet(isPresented: $showCalibrationRunner) {
                if let ex = liveExercise {
                    CalibrationRunnerView(manager: manager, exercise: ex)
                }
            }
            .onAppear {
                if let ex = exerciseToEdit {
                    name = ex.name
                    split = WorkoutSplit(rawValue: ex.split.uppercased()) ?? .push
                    muscleGroup = ex.muscleGroup
                    category = ex.category
                    equipment = ex.equipmentType
                    unit = ex.unit.lowercased()
                    microIncrement = ex.microIncrement
                    repWindowMin = ex.repWindowMin
                    repWindowMax = ex.repWindowMax
                    anchorWeight = ex.loads.first ?? ex.weight
                    isAssisted = ex.isAssisted
                    hasStackLimits = (ex.minWeight != nil || ex.maxWeight != nil)
                    let isKg = unit.lowercased() == "kg"
                    minWeight = ex.minWeight ?? (isKg ? 2.5 : 5.0)
                    maxWeight = ex.maxWeight ?? (isKg ? 50.0 : 100.0)

                    anchorWeightString = String(format: "%.1f", anchorWeight)
                    minWeightString = String(format: "%.1f", minWeight)
                    maxWeightString = String(format: "%.1f", maxWeight)
                    repMinString = "\(repWindowMin)"
                    repMaxString = "\(repWindowMax)"
                } else {
                    applyEquipmentDefaults(equipment)
                }
            }
        }
    }

    // MARK: - Calibration Actions Section

    private func calibrationActionSection(ex: Exercise) -> some View {
        Section(header: Text("CALIBRATION & RECALIBRATION").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.cyan)) {
            if ex.isCalibrated {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ACTIVE DPO BENCHMARK")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(Theme.emerald)
                            Text("e1RM: \(String(format: "%.1f", ex.e1RM)) \(ex.unit.uppercased()) • Fatigue: \(Int(round(ex.fatigueIndex * 100)))%")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        if ex.sessionsSinceRecalibration >= 5 {
                            Text("DUE (5+)")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Theme.amber)
                                .cornerRadius(4)
                        } else {
                            Text("\(ex.sessionsSinceRecalibration) SESSIONS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    // Recalibration Button
                    Button(action: {
                        Theme.hapticImpact(.medium)
                        showCalibrationRunner = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 14))
                            Text("Recalibrate Exercise (Run 2-Set Protocol)")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.cyan)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    // Reset Calibration
                    Button(action: {
                        manager.resetExerciseCalibration(id: ex.id)
                        Theme.hapticNotification(.warning)
                    }) {
                        Text("Reset to Uncalibrated")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.crimson)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STATUS: NOT CALIBRATED")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(Theme.amber)
                            Text("Run the 2-set failure protocol to benchmark 0-RIR capacity and determine fatigue drop.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }

                    // Calibration Button
                    Button(action: {
                        Theme.hapticImpact(.medium)
                        showCalibrationRunner = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.system(size: 14))
                            Text("Calibrate Exercise (Run 2-Set Benchmark)")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.emerald)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Reusable Keypad & Stepper Controls

    private func keypadStepper(
        value: Binding<Double>,
        textValue: Binding<String>,
        step: Double,
        floor: Double,
        ceil: Double,
        unit: String
    ) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                if value.wrappedValue - step >= floor - 0.01 {
                    let updated = max(floor, value.wrappedValue - step)
                    value.wrappedValue = updated
                    textValue.wrappedValue = String(format: "%.1f", updated)
                    Theme.hapticImpact(.light)
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(value.wrappedValue > floor ? Theme.crimson : Theme.textMuted.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(value.wrappedValue <= floor)

            TextField(String(format: "%.1f", value.wrappedValue), text: textValue)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .frame(minWidth: 58)
                .frame(height: 36)
                .padding(.horizontal, 4)
                .background(Theme.surfaceCard)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderHighlight, lineWidth: 1))
                .onChange(of: textValue.wrappedValue) { val in
                    if let parsed = Double(val.filter { $0.isNumber || $0 == "." }) {
                        value.wrappedValue = max(floor, min(ceil, parsed))
                    }
                }
                .onSubmit {
                    hideKeyboard()
                    syncStringsAfterKeyboardDismiss()
                }

            Text(unit)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textSecondary)

            Button(action: {
                if value.wrappedValue + step <= ceil + 0.01 {
                    let updated = min(ceil, value.wrappedValue + step)
                    value.wrappedValue = updated
                    textValue.wrappedValue = String(format: "%.1f", updated)
                    Theme.hapticImpact(.light)
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(value.wrappedValue < ceil ? Theme.emerald : Theme.textMuted.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(value.wrappedValue >= ceil)
        }
    }

    private func repKeypadStepper(
        value: Binding<Int>,
        textValue: Binding<String>,
        floor: Int,
        ceil: Int
    ) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                if value.wrappedValue > floor {
                    let updated = value.wrappedValue - 1
                    value.wrappedValue = updated
                    textValue.wrappedValue = "\(updated)"
                    Theme.hapticImpact(.light)
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(value.wrappedValue > floor ? Theme.crimson : Theme.textMuted.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(value.wrappedValue <= floor)

            TextField("\(value.wrappedValue)", text: textValue)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .frame(minWidth: 44)
                .frame(height: 36)
                .padding(.horizontal, 4)
                .background(Theme.surfaceCard)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderHighlight, lineWidth: 1))
                .onChange(of: textValue.wrappedValue) { val in
                    if let parsed = Int(val.filter { $0.isNumber }) {
                        value.wrappedValue = max(floor, min(ceil, parsed))
                    }
                }
                .onSubmit {
                    hideKeyboard()
                    syncStringsAfterKeyboardDismiss()
                }

            Text("reps")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textSecondary)

            Button(action: {
                if value.wrappedValue < ceil {
                    let updated = value.wrappedValue + 1
                    value.wrappedValue = updated
                    textValue.wrappedValue = "\(updated)"
                    Theme.hapticImpact(.light)
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(value.wrappedValue < ceil ? Theme.emerald : Theme.textMuted.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(value.wrappedValue >= ceil)
        }
    }

    private func syncStringsAfterKeyboardDismiss() {
        anchorWeightString = String(format: "%.1f", anchorWeight)
        minWeightString = String(format: "%.1f", minWeight)
        maxWeightString = String(format: "%.1f", maxWeight)
        repMinString = "\(repWindowMin)"
        repMaxString = "\(repWindowMax)"
    }

    private func applyEquipmentDefaults(_ eq: EquipmentType) {
        let isKg = unit.lowercased() == "kg"
        switch eq {
        case .barbell:
            microIncrement = isKg ? 1.25 : 2.5
        case .dumbbell:
            microIncrement = isKg ? 2.0 : 5.0
        case .cableStack, .machineLever:
            microIncrement = isKg ? 2.5 : 5.0
            if !isEditing && !hasStackLimits {
                hasStackLimits = true
                minWeight = isKg ? 5.0 : 10.0
                maxWeight = isKg ? 100.0 : 200.0
            }
        case .bodyweightLoaded:
            microIncrement = isKg ? 1.25 : 2.5
        }
        if minWeight <= 0 {
            minWeight = isKg ? 2.5 : 5.0
        }
        if maxWeight <= 20 {
            maxWeight = isKg ? 50.0 : 100.0
        }

        minWeightString = String(format: "%.1f", minWeight)
        maxWeightString = String(format: "%.1f", maxWeight)
    }

    private func saveExercise() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }

        let effectiveMin: Double? = (isAssisted || hasStackLimits) ? minWeight : nil
        let effectiveMax: Double? = (isAssisted || hasStackLimits) ? maxWeight : nil

        let loads: [Double]
        let w1: Double
        if isAssisted {
            w1 = min(maxWeight, max(minWeight, anchorWeight))
            let w2 = min(maxWeight, max(w1 + microIncrement, DPOEngine.roundToStep(w1 * 1.20, step: microIncrement)))
            let w3 = min(maxWeight, max(w2 + microIncrement, DPOEngine.roundToStep(w1 * 1.40, step: microIncrement)))
            loads = [w1, w2, w3]
        } else {
            let minW = hasStackLimits ? minWeight : 0.0
            let maxW = hasStackLimits ? maxWeight : Double.infinity
            w1 = min(maxW, max(minW, anchorWeight))
            let w2 = min(maxW, max(minW, DPOEngine.roundToStep(w1 * 0.80, step: microIncrement)))
            let w3 = min(maxW, max(minW, DPOEngine.roundToStep(w1 * 0.60, step: microIncrement)))
            loads = [w1, w2, w3]
        }

        if var ex = exerciseToEdit {
            ex.name = cleanName
            ex.split = split.rawValue
            ex.muscleGroup = muscleGroup
            ex.category = category
            ex.equipmentType = equipment
            ex.unit = unit
            ex.microIncrement = microIncrement
            ex.repWindowMin = repWindowMin
            ex.repWindowMax = repWindowMax
            ex.weight = w1
            ex.loads = loads
            ex.isAssisted = isAssisted
            ex.minWeight = effectiveMin
            ex.maxWeight = effectiveMax
            manager.updateExercise(ex)
        } else {
            let id = "\(split.rawValue.lowercased())-\(cleanName.lowercased().replacingOccurrences(of: " ", with: "-"))"
            let newEx = Exercise(
                id: id,
                name: cleanName,
                split: split.rawValue,
                category: category,
                equipmentType: equipment,
                unit: unit,
                microIncrement: microIncrement,
                repWindowMin: repWindowMin,
                repWindowMax: repWindowMax,
                activeSetsCount: 3,
                isCalibrated: false,
                e1RM: 0.0,
                fatigueIndex: 0.0,
                loads: loads,
                weight: w1,
                consecutiveSet3Failures: 0,
                consecutiveStagnations: 0,
                consecutivePromotions: 0,
                sessionsSinceRecalibration: 0,
                muscleGroup: muscleGroup,
                baseTareWeight: 0.0,
                isAssisted: isAssisted,
                minWeight: effectiveMin,
                maxWeight: effectiveMax
            )
            manager.addExercise(newEx)
        }
        dismiss()
    }
}
