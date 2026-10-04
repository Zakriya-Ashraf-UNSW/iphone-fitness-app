import SwiftUI

public struct TransitionRestView: View {
    @ObservedObject var manager: WorkoutSessionManager

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    private var formattedTime: String {
        let rem = max(0, manager.restTimerRemaining)
        let m = rem / 60
        let s = rem % 60
        return String(format: "%02d:%02d", m, s)
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text("INTER-EXERCISE RECOVERY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.sky)
                    .tracking(1.0)
                Text(formattedTime)
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Theme.textPrimary)
            }

            // Up Next Card
            VStack(spacing: 6) {
                Text("UP NEXT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                    .tracking(0.6)
                Text(manager.transitionNextExName)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Theme.surfaceCard)
            .cornerRadius(12)

            // CTA Button
            Button(action: { manager.skipTransitionRest() }) {
                HStack {
                    Spacer()
                    Text("Ready Now — Begin Next Lift ›")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(Theme.sky)
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Theme.surfaceElevated)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.sky.opacity(0.4), lineWidth: 1)
        )
    }
}
