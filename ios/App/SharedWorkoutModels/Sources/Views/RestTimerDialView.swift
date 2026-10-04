import SwiftUI

public struct RestTimerDialView: View {
    @ObservedObject var manager: WorkoutSessionManager

    private var formattedTime: String {
        let remaining = max(0, manager.restTimerRemaining)
        let mins = remaining / 60
        let secs = remaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private var progress: Double {
        guard manager.restTimerPrescribed > 0 else { return 0 }
        return Double(manager.restTimerRemaining) / Double(manager.restTimerPrescribed)
    }

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Header badge
            HStack(spacing: 6) {
                Circle()
                    .fill(manager.restTimerRunning ? Theme.amber : Theme.textMuted)
                    .frame(width: 8, height: 8)
                Text(manager.restTimerLabel.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(manager.restTimerRunning ? Theme.amber : Theme.textMuted)
                    .tracking(0.8)
                Spacer()
                if !manager.restTimerReason.isEmpty {
                    Text(manager.restTimerReason)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            HStack(spacing: 20) {
                // Dial ring
                ZStack {
                    Circle()
                        .stroke(Theme.border, lineWidth: 6)
                        .frame(width: 84, height: 84)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                        .stroke(
                            LinearGradient(
                                colors: [Theme.amber, Theme.amber.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: -90))
                        .frame(width: 84, height: 84)
                        .animation(.linear(duration: 0.5), value: progress)

                    Text(formattedTime)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Theme.textPrimary)
                }

                // Rest Controls
                VStack(alignment: .leading, spacing: 8) {
                    if manager.restTimerRunning {
                        HStack(spacing: 8) {
                            Button(action: { manager.adjustRest(by: 30) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("30s")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.surfaceCard)
                                .foregroundColor(Theme.textPrimary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                            }

                            Button(action: { manager.stopRestTimer() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 10))
                                    Text("Skip Rest")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.surfaceCard)
                                .foregroundColor(Theme.amber)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.amber.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    } else {
                        Text("Rest interval idle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        Text("Timer will auto-start upon logging your set")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Theme.surfaceElevated)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(manager.restTimerRunning ? Theme.amber.opacity(0.3) : Theme.border, lineWidth: 1)
        )
    }
}
