import SwiftUI

public struct ExerciseRecapView: View {
    @ObservedObject var manager: WorkoutSessionManager

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    private var outcome: ProgressionOutcome? {
        manager.recapOutcome
    }

    public var body: some View {
        VStack(spacing: 18) {
            // Celebration Icon & Title
            VStack(spacing: 6) {
                Image(systemName: outcome?.s1Adv == true ? "trophy.fill" : "shield.checkerboard")
                    .font(.system(size: 38))
                    .foregroundColor(outcome?.s1Adv == true ? Theme.emerald : Theme.amber)
                    .padding(.top, 4)

                Text(outcome?.s1Adv == true ? "OVERLOAD BREAKTHROUGH!" : "SET COMPLETED & CONSOLIDATED")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(outcome?.s1Adv == true ? Theme.emerald : Theme.amber)
                    .tracking(1.0)

                Text(manager.currentExercise?.name ?? "Exercise")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }

            // Next Anchor Load Bento Card
            if let o = outcome, let ex = manager.currentExercise {
                VStack(spacing: 8) {
                    Text("NEXT WORKOUT ANCHOR LOAD")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                        .tracking(0.6)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f %@", o.loads.first ?? ex.weight, ex.unit.uppercased()))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)

                        if o.s1Adv {
                            Text("(+\(String(format: "%.1f", ex.microIncrement)) \(ex.unit))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.emerald)
                        } else {
                            Text("(Maintained)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    Text(o.summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Theme.surfaceCard)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }

            // Logged Sets Summary
            HStack(spacing: 12) {
                setRepBadge(label: "SET 1", reps: manager.loggedReps[0])
                setRepBadge(label: "SET 2", reps: manager.loggedReps[1])
                if (manager.currentExercise?.activeSetsCount ?? 3) > 2 {
                    setRepBadge(label: "SET 3", reps: manager.loggedReps[2])
                }
            }

            // Continue CTA
            Button(action: { manager.advanceToNextExerciseAfterRecap() }) {
                HStack {
                    Spacer()
                    Text("Continue to Next Lift →")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(Theme.emerald)
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Theme.surfaceElevated)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.emerald.opacity(0.4), lineWidth: 1.5)
        )
    }

    private func setRepBadge(label: String, reps: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textMuted)
            Text("\(reps)r")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surfaceCard)
        .cornerRadius(8)
    }
}
