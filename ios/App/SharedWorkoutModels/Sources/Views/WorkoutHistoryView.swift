import SwiftUI

public struct WorkoutHistoryView: View {
    @State private var history: [WorkoutHistoryEntry] = []

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WORKOUT LOG")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.emerald)
                            .tracking(1.0)
                        Text("Session History")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Spacer()
                }
                .padding(.top, 8)

                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textMuted)
                        Text("No Logged Sessions Yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        Text("Complete an exercise in the Chamber to record your progressive overload journey.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(16)
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(history) { entry in
                            historyCard(entry)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            history = WorkoutStore.shared.loadHistory()
        }
    }

    private func historyCard(_ entry: WorkoutHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.exerciseName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(entry.dateString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }

            HStack(spacing: 8) {
                Text("S1: \(entry.set1Reps)r")
                Text("•")
                Text("S2: \(entry.set2Reps)r")
                if entry.targetSets > 2 {
                    Text("•")
                    Text("S3: \(entry.set3Reps)r")
                }
                Spacer()
                Text(String(format: "Next: %.1f %@", entry.nextTargetWeight, entry.unit.uppercased()))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.emerald)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(Theme.textSecondary)

            Text(entry.progressionSummary)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
        }
        .padding(14)
        .background(Theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}
