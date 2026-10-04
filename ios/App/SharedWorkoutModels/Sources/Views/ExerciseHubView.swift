import SwiftUI

public struct ExerciseHubView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @Binding var selectedTab: Int

    public init(manager: WorkoutSessionManager, selectedTab: Binding<Int>) {
        self.manager = manager
        self._selectedTab = selectedTab
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Split Selector
                splitSelector

                // Start Routine Banner
                routineBanner

                // Exercise Cards
                VStack(spacing: 12) {
                    ForEach(manager.exercisesForCurrentSplit) { exercise in
                        exerciseRow(exercise)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var splitSelector: some View {
        HStack(spacing: 8) {
            ForEach(WorkoutSplit.allCases) { split in
                Button(action: {
                    Theme.hapticImpact(.light)
                    manager.currentSplit = split
                    manager.activeExerciseIndex = 0
                }) {
                    Text(split.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(manager.currentSplit == split ? .black : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(manager.currentSplit == split ? Theme.emerald : Theme.surfaceElevated)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(manager.currentSplit == split ? Theme.emerald : Theme.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var routineBanner: some View {
        Button(action: {
            manager.startRoutine(split: manager.currentSplit)
            selectedTab = 0
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("START \(manager.currentSplit.rawValue) WORKOUT")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                    Text("\(manager.exercisesForCurrentSplit.count) Hypertrophy Lifts • Progressive Overload Active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.8))
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.black)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Theme.emerald, Theme.emerald.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(14)
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(exercise.muscleGroup) • \(exercise.category.rawValue.replacingOccurrences(of: "_", with: " "))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()

                Button(action: {
                    manager.startLift(exerciseId: exercise.id)
                    selectedTab = 0
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                        Text("Train")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.emerald.opacity(0.18))
                    .foregroundColor(Theme.emerald)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.emerald.opacity(0.4), lineWidth: 1)
                    )
                }
            }

            // Loads Badges
            HStack(spacing: 8) {
                loadBadge(label: "SET 1", load: exercise.loads.first ?? exercise.weight, unit: exercise.unit)
                if exercise.loads.count > 1 {
                    loadBadge(label: "SET 2", load: exercise.loads[1], unit: exercise.unit)
                }
                if exercise.loads.count > 2 && exercise.activeSetsCount > 2 {
                    loadBadge(label: "SET 3", load: exercise.loads[2], unit: exercise.unit)
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("e1RM")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                    Text(String(format: "%.0f %@", exercise.e1RM, exercise.unit))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding(14)
        .background(Theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func loadBadge(label: String, load: Double, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textMuted)
            Text(String(format: "%.1f", load))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceCard)
        .cornerRadius(6)
    }
}
