import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import SharedWorkoutModels
import os

private let logger = Logger(subsystem: "com.overload.fitnessapp.WorkoutWidgets", category: "Intents")

private let appGroupID = "group.com.overload.fitnessapp"

/// Writes an action to the shared App Group UserDefaults and posts a Darwin
/// notification so the main app can react even while backgrounded.
private func notifyAppOfAction(_ action: String, params: [String: String] = [:]) {
    guard let defaults = UserDefaults(suiteName: appGroupID) else {
        logger.error("Failed to access App Group UserDefaults")
        return
    }
    var payload = params
    payload["action"] = action
    payload["timestamp"] = String(Date().timeIntervalSince1970)
    defaults.set(payload, forKey: "pendingWidgetAction")
    defaults.synchronize()
    logger.info("Wrote pendingWidgetAction: \(action)")

    // Post a Darwin notification so the app can wake up and read the action
    let notificationName = CFNotificationName("com.overload.fitnessapp.widgetAction" as CFString)
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        notificationName,
        nil, nil, true
    )
}

// MARK: - App Intents for Dynamic Island Interactive Buttons
struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Rest"
    static var description: IntentDescription = "Immediately completes rest countdown"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        logger.info("SkipRestIntent triggered")
        let activities = Activity<WorkoutActivityAttributes>.activities
        logger.info("Found \(activities.count) activities")
        for activity in activities {
            logger.info("Updating activity: \(activity.id)")
            var state = activity.content.state
            state.isResting = false
            state.restEndTimestamp = nil
            state.isTriageLogging = true
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
            logger.info("Activity updated successfully")
        }
        // Notify the main app so it can update its JS state
        notifyAppOfAction("skip-rest")
        return .result()
    }
}


struct AdjustTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Adjust Rest Timer"
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Delta Seconds")
    var deltaSeconds: Int

    init() {}
    init(delta: Int) {
        self.deltaSeconds = delta
    }

    func perform() async throws -> some IntentResult {
        logger.info("AdjustTimerIntent called with adjustment: \(deltaSeconds)")
        let activities = Activity<WorkoutActivityAttributes>.activities
        logger.info("Found \(activities.count) activities")
        let now = Date().timeIntervalSince1970
        for activity in activities {
            logger.info("Updating activity: \(activity.id)")
            var state = activity.content.state
            let currentEnd = state.restEndTimestamp ?? (now + 60)
            let newEnd = max(now + 1, currentEnd + Double(deltaSeconds))
            state.restEndTimestamp = newEnd
            state.isResting = true
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
            logger.info("Activity updated successfully, new end: \(newEnd)")
        }
        notifyAppOfAction("adjust-timer", params: ["delta": String(deltaSeconds)])
        return .result()
    }
}


struct LogTriageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Set Outcome"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Outcome")
    var outcome: String // "missed", "target", "overload"

    init() {}
    init(outcome: String) {
        self.outcome = outcome
    }

    func perform() async throws -> some IntentResult {
        logger.info("LogTriageIntent triggered with outcome: \(outcome)")
        let activities = Activity<WorkoutActivityAttributes>.activities
        logger.info("Found \(activities.count) activities")
        for activity in activities {
            logger.info("Updating activity: \(activity.id)")
            var state = activity.content.state
            state.isTriageLogging = false
            state.isResting = true
            state.restEndTimestamp = Date().addingTimeInterval(90).timeIntervalSince1970
            if state.setIndex < state.totalSets {
                state.setIndex += 1
            }
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
            logger.info("Activity updated successfully")
        }
        notifyAppOfAction("log-triage", params: ["outcome": outcome])
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
                // Top Left (.leading): Split badge & Set counter hugging hardware pill
                // Top Right (.trailing): Green ring & Timer hugging top right hardware corner
                // Lower (.bottom): Exercise Title, Load/Target card, Action buttons
                // ==============================================================
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Text(context.state.splitName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                            .foregroundColor(.white)

                        Text("Set \(context.state.setIndex) of \(context.state.totalSets)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.65))
                    }
                    .padding(.leading, 2)
                    .padding(.top, 2)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 5) {
                        Circle()
                            .stroke(Color(red: 0.06, green: 0.72, blue: 0.51), lineWidth: 2.5)
                            .frame(width: 14, height: 14)

                        if let restEnd = context.state.restEndTimestamp {
                            let targetDate = Date(timeIntervalSince1970: restEnd)
                            Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.85)
                        } else {
                            Text("01:15")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 2)
                    .padding(.top, 2)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isTriageLogging {
                        TriageExpandedView(state: context.state)
                    } else {
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

// MARK: - SCREEN-03.3: Rest Countdown HUD Expanded View
struct RestCountdownExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            // Exercise Title spanning full width below physical hardware pill
            HStack {
                Text(state.exerciseName)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            // MIDDLE ROW: LOAD 115.0 LBS | Target 8-12 Reps
            HStack {
                HStack(spacing: 5) {
                    Text("LOAD")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                    Text(state.loadText)
                        .font(.system(size: 13, weight: .black, design: .rounded))
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
                        .padding(.vertical, 2)
                        .background(Color(red: 0.06, green: 0.72, blue: 0.51).opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundColor(Color(red: 0.43, green: 0.91, blue: 0.72))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 2)

            // BOTTOM ROW: Interactive [-15s], [+30s], [Skip Rest ▶] Buttons
            HStack(spacing: 6) {
                Button(intent: AdjustTimerIntent(delta: -15)) {
                    Text("-15s")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.99, green: 0.64, blue: 0.68))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(Color(red: 0.35, green: 0.08, blue: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(intent: AdjustTimerIntent(delta: 30)) {
                    Text("+30s")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.43, green: 0.91, blue: 0.72))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(Color(red: 0.05, green: 0.28, blue: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(intent: SkipRestIntent()) {
                    HStack(spacing: 4) {
                        Text("Skip Rest")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity * 1.3, minHeight: 32)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
    }
}

// MARK: - SCREEN-03.4: Quick-Log Rep Outcome Triage Expanded View
struct TriageExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            // Header Row: Set Completed Indicator
            HStack {
                Text("Set \(state.setIndex) of \(state.totalSets) Completed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(white: 0.7))

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 6)

            // Subheader: HOW DID THE SET GO? (ONE-TAP LOG)
            Text("HOW DID THE SET GO? (ONE-TAP LOG)")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(white: 0.7))

            // The 3 Triage Outcome Buttons
            HStack(spacing: 6) {
                // 1. Under Target (<8 Missed)
                Button(intent: LogTriageIntent(outcome: "missed")) {
                    VStack(spacing: 1) {
                        HStack(spacing: 2) {
                            Text("▼")
                                .font(.system(size: 8, weight: .bold))
                            Text(state.underTargetText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.99, green: 0.45, blue: 0.55))

                        Text("Under Target")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color(red: 0.85, green: 0.35, blue: 0.45))
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color(red: 0.25, green: 0.06, blue: 0.10).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(red: 0.96, green: 0.25, blue: 0.37), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // 2. Prescribed Reps (8-11 Target)
                Button(intent: LogTriageIntent(outcome: "target")) {
                    VStack(spacing: 1) {
                        HStack(spacing: 2) {
                            Text("🎯")
                                .font(.system(size: 9))
                            Text(state.prescribedTargetText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.35, green: 0.78, blue: 0.98))

                        Text("Prescribed Reps")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color(red: 0.25, green: 0.65, blue: 0.85))
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color(red: 0.05, green: 0.18, blue: 0.28).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(red: 0.22, green: 0.74, blue: 0.97), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // 3. Overload (12+ Overload)
                Button(intent: LogTriageIntent(outcome: "overload")) {
                    VStack(spacing: 1) {
                        HStack(spacing: 2) {
                            Text("🚀")
                                .font(.system(size: 9))
                            Text(state.overloadTargetText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.43, green: 0.91, blue: 0.72))

                        Text(state.overloadIncrementText)
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(Color(red: 0.06, green: 0.72, blue: 0.51))
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color(red: 0.04, green: 0.22, blue: 0.14).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(red: 0.06, green: 0.72, blue: 0.51), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)

            // Deep-link to full input modal in app
            Link(destination: URL(string: "overload://enter-exact")!) {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 9))
                    Text("Enter Exact Reps & Weight ›")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color(white: 0.7))
            }
            .padding(.bottom, 2)
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
