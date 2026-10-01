import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intents for Dynamic Island Interactive Buttons (iOS 17+)
@available(iOS 17.0, *)
struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Rest"
    static var description: IntentDescription = "Immediately completes rest countdown"

    func perform() async throws -> some IntentResult {
        // Broadcasts notification or triggers deep link back to app
        return .result()
    }
}

@available(iOS 17.0, *)
struct AdjustTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Rest Timer"
    
    @Parameter(title: "Delta Seconds")
    var deltaSeconds: Int

    init() {}
    init(delta: Int) {
        self.deltaSeconds = delta
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 17.0, *)
struct LogTriageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Set Outcome"

    @Parameter(title: "Outcome")
    var outcome: String // "missed", "target", "overload"

    init() {}
    init(outcome: String) {
        self.outcome = outcome
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Main Dynamic Island Widget for iPhone 16 Pro Max
public struct WorkoutLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // ==============================================================
            // LOCK SCREEN LIVE ACTIVITY BANNER (SCREEN-03.5 / SCREEN-03.6)
            // ==============================================================
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // ==============================================================
                // EXPANDED DYNAMIC ISLAND PRESENTATION
                // Width: ~371-398 pt, Corner Radius: 42-44 pt (iPhone 16 Pro Max)
                // ==============================================================
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }

                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isTriageLogging {
                        // SCREEN-03.4: Quick-Log Rep Outcome Triage (Image 2)
                        TriageExpandedView(state: context.state)
                    } else {
                        // SCREEN-03.3: Rest Countdown HUD (Image 3)
                        RestCountdownExpandedView(state: context.state)
                    }
                }
            } compactLeading: {
                // Compact Leading: Dumbbell / Gym icon + Set Badge
                HStack(spacing: 3) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundColor(Color(red: 0.06, green: 0.72, blue: 0.51))
                        .font(.system(size: 11, weight: .bold))
                    Text("S\(context.state.setIndex)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                // Compact Trailing: Live countdown or Target Weight
                if context.state.isResting, let restEnd = context.state.restEndTimestamp {
                    let targetDate = Date(timeIntervalSince1970: restEnd)
                    Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.06, green: 0.72, blue: 0.51))
                        .frame(minWidth: 42)
                        .padding(.trailing, 4)
                } else {
                    Text(context.state.loadText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                        .padding(.trailing, 4)
                }
            } minimal: {
                // Minimal (Concurrent bubble): Circle progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color(red: 0.06, green: 0.72, blue: 0.51), lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                    Text("S\(context.state.setIndex)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(width: 20, height: 20)
            }
            .keylineTint(Color(red: 0.06, green: 0.72, blue: 0.51))
        }
    }
}

// MARK: - SCREEN-03.3: Rest Countdown HUD Expanded View (Exact Match to Image 3)
struct RestCountdownExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            // TOP ROW: [PUSH] Set X of Y | Title | Right Timer (01:13)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(state.splitName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                            .foregroundColor(.white)

                        Text("Set \(state.setIndex) of \(state.totalSets)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.6))
                    }

                    Text(state.exerciseName)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                // Timer with Green Ring
                HStack(spacing: 6) {
                    Circle()
                        .stroke(Color(red: 0.06, green: 0.72, blue: 0.51), lineWidth: 3)
                        .frame(width: 16, height: 16)

                    if let restEnd = state.restEndTimestamp {
                        let targetDate = Date(timeIntervalSince1970: restEnd)
                        Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        Text("01:15")
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)

            // MIDDLE ROW: LOAD 115.0 LBS | Target 8-12 Reps
            HStack {
                HStack(spacing: 5) {
                    Text("LOAD")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                    Text(state.loadText)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()
                Divider()
                    .frame(height: 12)
                    .background(Color(white: 0.2))
                Spacer()

                HStack(spacing: 6) {
                    Text("Target")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                    Text(state.targetRepsText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.06, green: 0.72, blue: 0.51).opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundColor(Color(red: 0.43, green: 0.91, blue: 0.72))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 4)

            // BOTTOM ROW: [-15s], [+30s], [Skip Rest ▶]
            HStack(spacing: 8) {
                // -15s Button
                Button(intent: AdjustTimerIntent(delta: -15)) {
                    Text("-15s")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.99, green: 0.64, blue: 0.68))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color(red: 0.35, green: 0.08, blue: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // +30s Button
                Button(intent: AdjustTimerIntent(delta: 30)) {
                    Text("+30s")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.43, green: 0.91, blue: 0.72))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color(red: 0.05, green: 0.28, blue: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // Skip Rest Button (Prominent White Capsule)
                Button(intent: SkipRestIntent()) {
                    HStack(spacing: 4) {
                        Text("Skip Rest")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity * 1.5, minHeight: 36)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - SCREEN-03.4: Quick-Log Rep Outcome Triage Expanded View (Exact Match to Image 2)
struct TriageExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            // Header Row: [PUSH] Smith Incline · Set 2 of 3 Completed · [✓]
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(state.splitName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                            .foregroundColor(.white)

                        Text(state.exerciseName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Set \(state.setIndex) of \(state.totalSets) Completed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)

            // Subheader: HOW DID THE SET GO? (ONE-TAP LOG)
            Text("HOW DID THE SET GO? (ONE-TAP LOG)")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(white: 0.7))
                .padding(.top, 2)

            // The 3 Triage Outcome Buttons
            HStack(spacing: 8) {
                // 1. Under Target (<8 Missed)
                Button(intent: LogTriageIntent(outcome: "missed")) {
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Text("▼")
                                .font(.system(size: 9, weight: .bold))
                            Text(state.underTargetText)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.99, green: 0.45, blue: 0.55))

                        Text("Under Target")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(red: 0.85, green: 0.35, blue: 0.45))
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color(red: 0.25, green: 0.06, blue: 0.10).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.96, green: 0.25, blue: 0.37), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                // 2. Prescribed Reps (8-11 Target)
                Button(intent: LogTriageIntent(outcome: "target")) {
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Text("🎯")
                                .font(.system(size: 10))
                            Text(state.prescribedTargetText)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.35, green: 0.78, blue: 0.98))

                        Text("Prescribed Reps")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(red: 0.25, green: 0.65, blue: 0.85))
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color(red: 0.05, green: 0.18, blue: 0.28).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.22, green: 0.74, blue: 0.97), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                // 3. Overload (12+ Overload)
                Button(intent: LogTriageIntent(outcome: "overload")) {
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Text("🚀")
                                .font(.system(size: 10))
                            Text(state.overloadTargetText)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.43, green: 0.91, blue: 0.72))

                        Text(state.overloadIncrementText)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(Color(red: 0.06, green: 0.72, blue: 0.51))
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color(red: 0.04, green: 0.22, blue: 0.14).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.06, green: 0.72, blue: 0.51), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Deep-link to full input modal in app
            Link(destination: URL(string: "overload://enter-exact")!) {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                    Text("Enter Exact Reps & Weight ›")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(white: 0.7))
                .padding(.vertical, 3)
            }
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Lock Screen Banner View
struct LockScreenLiveActivityView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: state.isResting ? "timer" : "dumbbell.fill")
                    .foregroundColor(state.isResting ? Color(red: 0.06, green: 0.72, blue: 0.51) : Color(red: 0.22, green: 0.74, blue: 0.97))
                    .font(.system(size: 20, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(state.splitName)
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                    Text(state.exerciseName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                HStack(spacing: 6) {
                    Text("Set \(state.setIndex) of \(state.totalSets)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("•")
                        .foregroundColor(.gray)
                    Text(state.loadText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                }
            }

            Spacer()

            if state.isResting, let restEnd = state.restEndTimestamp {
                let targetDate = Date(timeIntervalSince1970: restEnd)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REST")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.06, green: 0.72, blue: 0.51))
                    Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("GOAL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(state.targetRepsText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
    }
}
