import SwiftUI

public struct WorkoutChamberView: View {
    @ObservedObject var manager: WorkoutSessionManager

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top HUD Bar
                topNavBar

                // Main Chamber Content
                if manager.isTransitionRestMode {
                    TransitionRestView(manager: manager)
                        .transition(.scale)
                } else if manager.isRecapShowing {
                    ExerciseRecapView(manager: manager)
                        .transition(.scale)
                } else {
                    // Continuous Rest Timer Dial
                    RestTimerDialView(manager: manager)

                    if manager.isWarmupMode {
                        WarmupChamberView(manager: manager)
                            .transition(.opacity)
                    } else {
                        // Set Selector Tabs
                        setSelectorPills

                        WorkingChamberView(manager: manager, setNumber: manager.activeSetIndex)
                            .id("working-chamber-\(manager.currentExercise?.id ?? "")-\(manager.activeSetIndex)")
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.activeSetIndex)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.isWarmupMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.isRecapShowing)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: manager.isTransitionRestMode)
        .sheet(isPresented: $manager.showCustomRepsSheet) {
            ExactRepsInputSheet(manager: manager)
        }
        .fullScreenCover(isPresented: $manager.isEndWorkoutSummaryShowing) {
            EndWorkoutSummaryView(manager: manager)
        }
    }

    private var topNavBar: some View {
        HStack(spacing: 12) {
            // Split Pill
            Text(manager.currentSplit.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.emerald)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.emerald.opacity(0.15))
                .cornerRadius(6)

            // Exercise Title
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.currentExercise?.name ?? "No Exercise")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(manager.currentExercise?.muscleGroup ?? "") • Lift \(manager.activeExerciseIndex + 1) of \(manager.exercisesForCurrentSplit.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            // Exercise navigation buttons & End Workout shortcut
            HStack(spacing: 6) {
                if manager.isRoutineActive && !manager.sessionCompletedExercises.isEmpty {
                    Button(action: {
                        manager.finishWorkoutAndShowSummary()
                    }) {
                        Text("Finish")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.emerald)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Theme.emerald.opacity(0.15))
                            .cornerRadius(6)
                    }
                }

                Button(action: {
                    if manager.activeExerciseIndex > 0 {
                        manager.activeExerciseIndex -= 1
                        manager.initCurrentExercise()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(manager.activeExerciseIndex > 0 ? Theme.textPrimary : Theme.textMuted)
                        .frame(width: 32, height: 32)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(8)
                }
                .disabled(manager.activeExerciseIndex <= 0)

                Button(action: {
                    if manager.activeExerciseIndex < manager.exercisesForCurrentSplit.count - 1 {
                        manager.activeExerciseIndex += 1
                        manager.initCurrentExercise()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(manager.activeExerciseIndex < manager.exercisesForCurrentSplit.count - 1 ? Theme.textPrimary : Theme.textMuted)
                        .frame(width: 32, height: 32)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(8)
                }
                .disabled(manager.activeExerciseIndex >= manager.exercisesForCurrentSplit.count - 1)
            }
        }
        .padding(.vertical, 8)
    }

    private var setSelectorPills: some View {
        HStack(spacing: 8) {
            let total = manager.currentExercise?.activeSetsCount ?? 3
            ForEach(1...total, id: \.self) { s in
                Button(action: { manager.goToSet(s) }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(setDotColor(s))
                            .frame(width: 6, height: 6)
                        Text("Set \(s)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(manager.activeSetIndex == s ? .black : Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(manager.activeSetIndex == s ? Theme.emerald : Theme.surfaceElevated)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(manager.activeSetIndex == s ? Theme.emerald : Theme.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func setDotColor(_ setNum: Int) -> Color {
        let logged: Bool
        switch setNum {
        case 1: logged = manager.s1Outcome != nil
        case 2: logged = manager.s2Outcome != nil
        default: logged = manager.s3Outcome != nil
        }
        if manager.activeSetIndex == setNum { return .black }
        return logged ? Theme.emerald : Theme.textMuted
    }
}

public struct ExactRepsInputSheet: View {
    @ObservedObject var manager: WorkoutSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var reps: Int = 8
    @State private var repsString: String = "8"

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
        let ex = manager.currentExercise
        let idx = manager.activeSetIndex - 1
        let initial: Int
        if let ex = ex {
            if manager.loggedReps.indices.contains(idx) && manager.loggedReps[idx] > 0 {
                initial = manager.loggedReps[idx]
            } else {
                initial = ex.repWindowMax
            }
        } else {
            initial = 8
        }
        _reps = State(initialValue: initial)
        _repsString = State(initialValue: "\(initial)")
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    if let ex = manager.currentExercise {
                        VStack(spacing: 4) {
                            Text("SET \(manager.activeSetIndex) PERFORMANCE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.emerald)
                                .tracking(1.0)
                            Text(ex.name)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("Prescribed Window: \(ex.repWindowMin)–\(ex.repWindowMax) Reps")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 16)

                        // Reps input
                        VStack(spacing: 12) {
                            Text("REPS COMPLETED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textMuted)

                            HStack(spacing: 20) {
                                Button(action: {
                                    if reps > 1 {
                                        reps -= 1
                                        repsString = "\(reps)"
                                        Theme.hapticImpact(.light)
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 38))
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)

                                TextField("\(reps)", text: $repsString)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 48, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(minWidth: 80)
                                    .frame(height: 56)
                                    .background(Theme.surfaceCard)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderHighlight, lineWidth: 1))
                                    .onChange(of: repsString) { val in
                                        if let parsed = Int(val.filter { $0.isNumber }) {
                                            reps = max(0, parsed)
                                        }
                                    }
                                    .onSubmit {
                                        hideKeyboard()
                                        repsString = "\(reps)"
                                    }

                                Button(action: {
                                    reps += 1
                                    repsString = "\(reps)"
                                    Theme.hapticImpact(.light)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 38))
                                        .foregroundColor(Theme.emerald)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(16)

                        // Outcome preview
                        let repMin = ex.repWindowMin
                        let repMax = ex.repWindowMax
                        let outcome: String = reps > repMax ? "overload" : (reps >= repMin ? "target" : "missed")
                        let badgeColor: Color = outcome == "overload" ? Theme.purple : (outcome == "target" ? Theme.emerald : Theme.sky)
                        let badgeTitle: String = outcome == "overload" ? "Hypertrophy Overload Cleared" : (outcome == "target" ? "Prescribed Window Met" : "Under Target Threshold")

                        HStack(spacing: 8) {
                            Circle().fill(badgeColor).frame(width: 8, height: 8)
                            Text(badgeTitle)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(badgeColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(badgeColor.opacity(0.12))
                        .clipShape(Capsule())

                        Spacer()

                        Button(action: {
                            hideKeyboard()
                            if manager.activeSetIndex == 1 {
                                manager.logSet1(outcome: outcome, customReps: reps)
                            } else if manager.activeSetIndex == 2 {
                                manager.logSet2(outcome: outcome, customReps: reps)
                            } else {
                                manager.logSet3(outcome: outcome, customReps: reps)
                            }
                            manager.showCustomRepsSheet = false
                            dismiss()
                        }) {
                            Text("Confirm & Start Rest →")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.emerald)
                                .cornerRadius(14)
                        }
                        .padding(.bottom, 16)
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Log Exact Reps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        manager.showCustomRepsSheet = false
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                        repsString = "\(reps)"
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.emerald)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            let idx = manager.activeSetIndex - 1
            if let ex = manager.currentExercise {
                if manager.loggedReps.indices.contains(idx) && manager.loggedReps[idx] > 0 {
                    reps = manager.loggedReps[idx]
                } else {
                    reps = ex.repWindowMax
                }
                repsString = "\(reps)"
            }
        }
    }
}

