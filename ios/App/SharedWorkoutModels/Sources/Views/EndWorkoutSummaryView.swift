import SwiftUI

public struct EndWorkoutSummaryView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @Environment(\.dismiss) private var dismiss

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    private var summaries: [SessionExerciseSummary] {
        if !manager.sessionCompletedExercises.isEmpty {
            return manager.sessionCompletedExercises
        }
        // Fallback: If opened without in-memory items, reconstruct from recent session history
        let recent = WorkoutStore.shared.loadHistory().prefix(manager.exercisesForCurrentSplit.count)
        return recent.map { h in
            let sets = h.targetSets
            let reps: [Int] = [
                Int(h.set1Reps) ?? 0,
                Int(h.set2Reps) ?? 0,
                Int(h.set3Reps) ?? 0
            ]
            let deltas = (0..<sets).map { i -> Double in
                let used = h.loadsUsed.indices.contains(i) ? h.loadsUsed[i] : h.weightUsed
                let next = h.nextLoads.indices.contains(i) ? h.nextLoads[i] : used
                return next - used
            }
            return SessionExerciseSummary(
                exerciseId: h.exerciseId,
                exerciseName: h.exerciseName,
                muscleGroup: h.split,
                split: h.split,
                unit: h.unit,
                targetSets: sets,
                loggedReps: Array(reps.prefix(sets)),
                loadsUsed: h.loadsUsed,
                nextLoads: h.nextLoads,
                deltas: deltas,
                progressionSummary: h.progressionSummary,
                isAnchorPromoted: (h.isAssisted == true ? ((deltas.first ?? 0) < 0) : ((deltas.first ?? 0) > 0)),
                isAssisted: h.isAssisted ?? false
            )
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: - Hero Celebration Card
                        heroCelebrationCard

                        // MARK: - Color Legend Card
                        colorLegendCard

                        // MARK: - Exercises & Progression Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("COMPLETED EXERCISES & TARGET ADJUSTMENTS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.textMuted)
                                    .tracking(0.8)

                                Spacer()

                                Text("\(summaries.count) Lifts")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.horizontal, 4)

                            if summaries.isEmpty {
                                emptyStateCard
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(summaries) { summary in
                                        exerciseSummaryCard(summary)
                                    }
                                }
                            }
                        }

                        // MARK: - Done CTA Button
                        Button(action: {
                            Theme.hapticNotification(.success)
                            manager.dismissEndWorkoutSummary()
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Done • Return to Dashboard")
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.emerald)
                            .cornerRadius(16)
                            .shadow(color: Theme.emerald.opacity(0.35), radius: 12, y: 4)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Workout Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Theme.hapticNotification(.success)
                        manager.dismissEndWorkoutSummary()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.emerald)
                }
            }
        }
    }

    // MARK: - Hero Header
    private var heroCelebrationCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.emerald.opacity(0.12))
                    .frame(width: 80, height: 80)

                Circle()
                    .stroke(Theme.emerald.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 80, height: 80)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Theme.emerald)
            }
            .padding(.top, 8)

            VStack(spacing: 4) {
                Text("WORKOUT COMPLETE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.emerald)
                    .tracking(1.4)

                Text(manager.currentSplit.displayName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(Date().formatted(date: .complete, time: .shortened))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }

            // Quick Stats Row
            HStack(spacing: 12) {
                statTile(
                    label: "EXERCISES",
                    value: "\(summaries.count)",
                    color: Theme.emerald
                )

                let totalSets = summaries.reduce(0) { $0 + $1.targetSets }
                statTile(
                    label: "SETS LOGGED",
                    value: "\(totalSets)",
                    color: Theme.sky
                )

                let promotions = summaries.filter { ($0.deltas.first ?? 0) > 0 }.count
                statTile(
                    label: "PROMOTIONS",
                    value: "+\(promotions)",
                    color: Theme.amber
                )
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.surfaceElevated)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.emerald.opacity(0.3), lineWidth: 1)
        )
    }

    private func statTile(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textMuted)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surfaceCard)
        .cornerRadius(10)
    }

    // MARK: - Color Legend Card
    private var colorLegendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TARGET WEIGHT PROGRESSION KEY")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textMuted)
                .tracking(0.8)

            HStack(spacing: 12) {
                legendItem(
                    color: Theme.emerald,
                    label: "Load Increase",
                    icon: "arrow.up.right"
                )

                legendItem(
                    color: Color.white,
                    label: "Same Load",
                    icon: "equal"
                )

                legendItem(
                    color: Theme.crimson,
                    label: "Load Decrease",
                    icon: "arrow.down.right"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func legendItem(color: Color, label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Exercise Summary Card
    private func exerciseSummaryCard(_ summary: SessionExerciseSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Exercise Name & Muscle Group
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(summary.exerciseName)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)

                        if summary.isAssisted {
                            Text("ASSIST")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.purple)
                                .cornerRadius(4)
                        }
                    }

                    Text(summary.muscleGroup.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                        .tracking(0.6)
                }

                Spacer()

                if summary.isAnchorPromoted {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                        Text(summary.isAssisted ? "OVERLOAD (-ASSIST)" : "PROMOTED")
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .foregroundColor(Theme.emerald)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.emerald.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            // MARK: Logged Reps Row
            VStack(alignment: .leading, spacing: 6) {
                Text("LOGGED REPS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                    .tracking(0.6)

                HStack(spacing: 8) {
                    ForEach(0..<summary.targetSets, id: \.self) { i in
                        let reps = summary.loggedReps.indices.contains(i) ? summary.loggedReps[i] : 0
                        HStack(spacing: 4) {
                            Text("S\(i + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            Text("\(reps) reps")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(8)
                    }
                }
            }

            Divider()
                .background(Theme.border)

            // MARK: Next Session Target Weights & Deltas
            VStack(alignment: .leading, spacing: 8) {
                Text("NEXT SESSION TARGET LOADS & CHANGES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                    .tracking(0.6)

                VStack(spacing: 8) {
                    ForEach(0..<summary.targetSets, id: \.self) { i in
                        let used = summary.loadsUsed.indices.contains(i) ? summary.loadsUsed[i] : 0.0
                        let next = summary.nextLoads.indices.contains(i) ? summary.nextLoads[i] : used
                        let delta = summary.deltas.indices.contains(i) ? summary.deltas[i] : (next - used)

                        setTargetRow(
                            setIndex: i + 1,
                            loadUsed: used,
                            nextTarget: next,
                            delta: delta,
                            unit: summary.unit,
                            isAssisted: summary.isAssisted
                        )
                    }
                }
            }

            // Progression Summary Note
            if !summary.progressionSummary.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                        .padding(.top, 1)

                    Text(summary.progressionSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(summary.isAnchorPromoted ? Theme.emerald.opacity(0.3) : Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Set Target Row
    private func setTargetRow(
        setIndex: Int,
        loadUsed: Double,
        nextTarget: Double,
        delta: Double,
        unit: String,
        isAssisted: Bool = false
    ) -> some View {
        let fgColor = loadChangeColor(delta: delta, isAssisted: isAssisted)
        let bgColor = loadChangeBgColor(delta: delta, isAssisted: isAssisted)

        return HStack(alignment: .center) {
            // Set label
            Text("SET \(setIndex)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 44, alignment: .leading)

            // Current Lifted -> Next Target
            HStack(spacing: 6) {
                Text(String(format: "%.1f", loadUsed))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textMuted)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textMuted)

                Text(String(format: "%.1f %@", nextTarget, unit))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(fgColor)

                if isAssisted {
                    Text("ast")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.purple)
                }
            }

            Spacer()

            // Change Pill (Green for overload/improvement, White for same, Red for regression)
            HStack(spacing: 4) {
                Image(systemName: deltaIcon(delta: delta, isAssisted: isAssisted))
                    .font(.system(size: 10, weight: .bold))

                Text(formatDeltaText(delta: delta, unit: unit, isAssisted: isAssisted))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(fgColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(bgColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(fgColor.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
        .cornerRadius(10)
    }

    // MARK: - Color & Formatting Helpers
    private func loadChangeColor(delta: Double, isAssisted: Bool = false) -> Color {
        if isAssisted {
            if delta < -0.001 {
                return Theme.emerald // Less assistance pin = overload
            } else if delta > 0.001 {
                return Theme.crimson // More assistance pin = compensatory aid
            } else {
                return Color.white
            }
        } else {
            if delta > 0.001 {
                return Theme.emerald // Increase in weight
            } else if delta < -0.001 {
                return Theme.crimson // Decrease in weight
            } else {
                return Color.white
            }
        }
    }

    private func loadChangeBgColor(delta: Double, isAssisted: Bool = false) -> Color {
        if isAssisted {
            if delta < -0.001 {
                return Theme.emerald.opacity(0.18)
            } else if delta > 0.001 {
                return Theme.crimson.opacity(0.18)
            } else {
                return Color.white.opacity(0.10)
            }
        } else {
            if delta > 0.001 {
                return Theme.emerald.opacity(0.18)
            } else if delta < -0.001 {
                return Theme.crimson.opacity(0.18)
            } else {
                return Color.white.opacity(0.10)
            }
        }
    }

    private func deltaIcon(delta: Double, isAssisted: Bool = false) -> String {
        if isAssisted {
            if delta < -0.001 {
                return "arrow.down.right" // Downward pin = graduation
            } else if delta > 0.001 {
                return "arrow.up.right" // Upward pin = more assistance
            } else {
                return "equal"
            }
        } else {
            if delta > 0.001 {
                return "arrow.up.right"
            } else if delta < -0.001 {
                return "arrow.down.right"
            } else {
                return "equal"
            }
        }
    }

    private func formatDeltaText(delta: Double, unit: String, isAssisted: Bool = false) -> String {
        if isAssisted {
            if delta < -0.001 {
                return String(format: "%.1f %@ (Overload)", delta, unit)
            } else if delta > 0.001 {
                return String(format: "+%.1f %@ (+Assist)", delta, unit)
            } else {
                return "Same Pin"
            }
        } else {
            if delta > 0.001 {
                return String(format: "+%.1f %@", delta, unit)
            } else if delta < -0.001 {
                return String(format: "%.1f %@", delta, unit)
            } else {
                return "Same (0.0)"
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell")
                .font(.system(size: 28))
                .foregroundColor(Theme.textMuted)
            Text("No exercise data recorded for this session yet.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
    }
}
