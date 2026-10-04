import SwiftUI

public struct WarmupChamberView: View {
    @ObservedObject var manager: WorkoutSessionManager

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    private var currentWarmup: WarmupSet? {
        guard let p = manager.warmupPrescription, p.warmups.indices.contains(manager.warmupIndex - 1) else { return nil }
        return p.warmups[manager.warmupIndex - 1]
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEURAL PREPARATION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.amber)
                        .tracking(1.0)
                    Text("Warm-Up \(manager.warmupIndex) of \(manager.totalWarmups)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                Button(action: { manager.skipWarmups() }) {
                    Text("Skip Warm-Ups")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceCard)
                        .cornerRadius(8)
                }
            }

            // Target Load Card
            if let w = currentWarmup, let ex = manager.currentExercise {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TARGET LOAD")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                            .tracking(0.5)
                        Text(String(format: "%.1f %@", w.load, ex.unit.uppercased()))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Divider()
                        .frame(height: 36)
                        .background(Theme.border)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("REPS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                            .tracking(0.5)
                        Text("\(w.targetReps) reps")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Spacer()

                    Text(w.pct)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.amber.opacity(0.15))
                        .cornerRadius(8)
                }
                .padding(16)
                .background(Theme.surfaceCard)
                .cornerRadius(12)
            }

            // Action Button
            if manager.restTimerRunning {
                Button(action: { manager.advanceWarmup() }) {
                    HStack {
                        Spacer()
                        Text(manager.warmupIndex < manager.totalWarmups ? "▶ Ready for Warm-Up \(manager.warmupIndex + 1) ›" : "▶ Ready for Set 1 (Anchor) ›")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(Theme.amber)
                    .cornerRadius(12)
                }
            } else {
                Button(action: { manager.completeWarmupSet() }) {
                    HStack {
                        Spacer()
                        Text("✓ Complete Warm-Up \(manager.warmupIndex) & Start Rest (\(manager.restTimerPrescribed)s)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(Theme.emerald)
                    .cornerRadius(12)
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
    }
}
