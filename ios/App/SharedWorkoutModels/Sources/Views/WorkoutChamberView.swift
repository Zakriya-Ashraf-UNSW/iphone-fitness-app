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

            // Exercise navigation buttons
            HStack(spacing: 6) {
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
