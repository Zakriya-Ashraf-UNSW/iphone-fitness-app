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
    @State private var showDeleteConfirm: Bool = false

    private var isEditing: Bool { exerciseToEdit != nil }

    public init(manager: WorkoutSessionManager, exerciseToEdit: Exercise? = nil) {
        self.manager = manager
        self.exerciseToEdit = exerciseToEdit
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
                }
                .listRowBackground(Theme.surfaceElevated)

                // Section 3: Rep Target Window & Working Load
                Section(header: Text("TARGET CADENCE & LOADS").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.emerald)) {
                    HStack {
                        Text("Rep Window Min (R_min)")
                        Spacer()
                        Stepper("\(repWindowMin) reps", value: $repWindowMin, in: 3...20)
                    }

                    HStack {
                        Text("Rep Window Max (R_max)")
                        Spacer()
                        Stepper("\(repWindowMax) reps", value: $repWindowMax, in: repWindowMin...30)
                    }

                    HStack {
                        Text("Anchor Working Load (W1)")
                        Spacer()
                        Stepper("\(String(format: "%.1f", anchorWeight)) \(unit)", value: $anchorWeight, in: 5...300, step: microIncrement)
                    }
                }
                .listRowBackground(Theme.surfaceElevated)

                // Section 4: Invariant Cascades Preview
                Section(header: Text("STARTING INVARIANT CASCADES").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.sky)) {
                    let w1 = anchorWeight
                    let w2 = DPOEngine.roundToStep(w1 * 0.80, step: microIncrement)
                    let w3 = DPOEngine.roundToStep(w1 * 0.60, step: microIncrement)

                    HStack {
                        Text("W1 Anchor")
                        Spacer()
                        Text("\(String(format: "%.1f", w1)) \(unit)").bold().foregroundColor(Theme.emerald)
                    }
                    HStack {
                        Text("W2 Intermediate (≥ 80%)")
                        Spacer()
                        Text("\(String(format: "%.1f", w2)) \(unit)").bold().foregroundColor(Theme.cyan)
                    }
                    HStack {
                        Text("W3 Base (≥ 60%)")
                        Spacer()
                        Text("\(String(format: "%.1f", w3)) \(unit)").bold().foregroundColor(Theme.amber)
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
                } else {
                    applyEquipmentDefaults(equipment)
                }
            }
        }
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
        case .bodyweightLoaded:
            microIncrement = isKg ? 1.25 : 2.5
        }
    }

    private func saveExercise() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }

        let w1 = anchorWeight
        let w2 = DPOEngine.roundToStep(w1 * 0.80, step: microIncrement)
        let w3 = DPOEngine.roundToStep(w1 * 0.60, step: microIncrement)
        let loads = [w1, w2, w3]

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
                muscleGroup: muscleGroup
            )
            manager.addExercise(newEx)
        }
        dismiss()
    }
}
