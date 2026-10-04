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

    // Maintain FIFO queue of pending actions so multiple actions while backgrounded are preserved
    var queue = defaults.array(forKey: "pendingWidgetActionsQueue") as? [[String: String]] ?? []
    queue.append(payload)
    defaults.set(queue, forKey: "pendingWidgetActionsQueue")

    // Keep single key for backwards compatibility
    defaults.set(payload, forKey: "pendingWidgetAction")
    defaults.synchronize()
    logger.info("Wrote pendingWidgetAction: \(action) (queue length: \(queue.count))")

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
            if state.setIndex < state.totalSets {
                state.setIndex += 1
                state.isResting = true
                state.restEndTimestamp = Date().addingTimeInterval(90).timeIntervalSince1970
            } else {
                state.isRecap = true
                state.isResting = false
                state.restEndTimestamp = nil
            }
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
            logger.info("Activity updated successfully")
        }
        notifyAppOfAction("log-triage", params: ["outcome": outcome])
        return .result()
    }
}

struct ContinueNextExerciseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Continue to Next Lift"
    static var description: IntentDescription = "Advances to the next exercise after viewing progression recap"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        logger.info("ContinueNextExerciseIntent triggered")
        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isRecap = false
            state.isTransitionRest = false
            state.setIndex = 1
            state.isResting = false
            state.restEndTimestamp = nil
            state.isTriageLogging = false
            if !state.nextExerciseName.isEmpty {
                state.exerciseName = state.nextExerciseName
                state.nextExerciseName = ""
            }
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
        notifyAppOfAction("continue-next-exercise")
        return .result()
    }
}

struct LogWarmupIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Warm-Up"
    static var description: IntentDescription = "Logs the current warm-up set and starts prescribed rest"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        logger.info("LogWarmupIntent triggered")
        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isResting = true
            state.restEndTimestamp = Date().addingTimeInterval(60).timeIntervalSince1970
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
        notifyAppOfAction("log-warmup")
        return .result()
    }
}

struct SkipWarmupsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Warm-Ups"
    static var description: IntentDescription = "Skips warm-ups and begins Anchor Set 1"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        logger.info("SkipWarmupsIntent triggered")
        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities {
            var state = activity.content.state
            state.isWarmup = false
            state.setIndex = 1
            state.isResting = false
            state.restEndTimestamp = nil
            state.isTriageLogging = false
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
        notifyAppOfAction("skip-warmup")
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
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                            .foregroundColor(.white)

                        if context.state.isTransitionRest {
                            Text("Next Lift Prep")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.orange)
                        } else if context.state.isWarmup {
                            Text("Warm-Up \(context.state.warmupIndex) of \(context.state.totalWarmups)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.orange)
                        } else if context.state.isRecap {
                            Text("Lift Recap")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
                        } else {
                            Text("Set \(context.state.setIndex) of \(context.state.totalSets)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(white: 0.65))
                        }
                    }
                    .padding(.leading, 3)
                    .padding(.top, 1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isTransitionRest, let restEnd = context.state.restEndTimestamp {
                        let targetDate = Date(timeIntervalSince1970: restEnd)
                        Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .shadow(color: Color.orange.opacity(0.45), radius: 3, x: 0, y: 0)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 1)
                    } else if context.state.isWarmup {
                        if context.state.isResting, let restEnd = context.state.restEndTimestamp {
                            let targetDate = Date(timeIntervalSince1970: restEnd)
                            Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundColor(Color.orange)
                                .shadow(color: Color.orange.opacity(0.45), radius: 3, x: 0, y: 0)
                                .minimumScaleFactor(0.85)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 1)
                        } else {
                            Text("W\(context.state.warmupIndex) PREP")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(Color.orange)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 1)
                        }
                    } else if context.state.isRecap {
                        Text(context.state.recapNextTargetText.isEmpty ? "Complete ✓" : context.state.recapNextTargetText)
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 1)
                    } else if let restEnd = context.state.restEndTimestamp {
                        let targetDate = Date(timeIntervalSince1970: restEnd)
                        Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .shadow(color: Color.orange.opacity(0.45), radius: 3, x: 0, y: 0)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 1)
                    } else {
                        Text("01:15")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .shadow(color: Color.orange.opacity(0.45), radius: 3, x: 0, y: 0)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isTransitionRest {
                        TransitionRestExpandedView(state: context.state)
                    } else if context.state.isWarmup {
                        WarmupExpandedView(state: context.state)
                    } else if context.state.isRecap {
                        ProgressionRecapExpandedView(state: context.state)
                    } else if context.state.isTriageLogging {
                        TriageExpandedView(state: context.state)
                    } else {
                        RestCountdownExpandedView(state: context.state)
                    }
                }
            } compactLeading: {
                if context.state.isTransitionRest {
                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .foregroundColor(Color.orange)
                            .font(.system(size: 9.5, weight: .black))
                        Text(context.state.nextExerciseName.isEmpty ? "Next Lift" : context.state.nextExerciseName)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 3)
                } else if context.state.isWarmup {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Color.orange)
                            .font(.system(size: 9.5, weight: .black))
                        Text("W\(context.state.warmupIndex)")
                            .font(.system(size: 10.5, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(Color(white: 0.45))
                        Text(context.state.exerciseName)
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(white: 0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.leading, 3)
                } else if context.state.isRecap {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
                            .font(.system(size: 10, weight: .black))
                        Text(context.state.exerciseName)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 3)
                } else {
                    // Compact Leading: Dumbbell icon + Set Badge + Exercise Name
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 10, weight: .bold))

                        Text("S\(context.state.setIndex)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.white)

                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(Color(white: 0.45))

                        Text(context.state.exerciseName)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(white: 0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.leading, 3)
                }
            } compactTrailing: {
                if context.state.isTransitionRest, let restEnd = context.state.restEndTimestamp {
                    let targetDate = Date(timeIntervalSince1970: restEnd)
                    Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                        .font(.system(size: 11.5, weight: .black, design: .monospaced))
                        .foregroundColor(Color.orange)
                        .shadow(color: Color.orange.opacity(0.4), radius: 2)
                        .padding(.trailing, 3)
                } else if context.state.isWarmup {
                    if context.state.isResting, let restEnd = context.state.restEndTimestamp {
                        let targetDate = Date(timeIntervalSince1970: restEnd)
                        Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                            .font(.system(size: 11.5, weight: .black, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .shadow(color: Color.orange.opacity(0.4), radius: 2)
                            .padding(.trailing, 3)
                    } else {
                        Text(context.state.loadText)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .lineLimit(1)
                            .padding(.trailing, 3)
                    }
                } else if context.state.isRecap {
                    Text(context.state.recapIsFinalExercise ? "Finish 🏆" : "Next Lift →")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
                        .padding(.trailing, 3)
                } else {
                    // Compact Trailing: Rep Range Pill + Load + Live countdown/Status
                    HStack(spacing: 5) {
                        // Mini Rep Range Pill
                        HStack(spacing: 2) {
                            Image(systemName: "repeat")
                                .font(.system(size: 7, weight: .black))
                            Text(compactRepRange(context.state.targetRepsText))
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(white: 0.18))
                        .overlay(
                            Capsule().stroke(Color(white: 0.38), lineWidth: 0.8)
                        )
                        .clipShape(Capsule())
                        .foregroundColor(.white)

                        // Load Text
                        Text(context.state.loadText)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.85))
                            .lineLimit(1)

                        // Countdown timer or Triage status
                        if context.state.isResting, let restEnd = context.state.restEndTimestamp {
                            let targetDate = Date(timeIntervalSince1970: restEnd)
                            Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                                .font(.system(size: 11.5, weight: .black, design: .monospaced))
                                .foregroundColor(Color.orange)
                                .shadow(color: Color.orange.opacity(0.4), radius: 2)
                                .frame(minWidth: 36)
                        } else if context.state.isTriageLogging {
                            Text("LOG")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 3)
                }
            } minimal: {
                if context.state.isTransitionRest {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.orange)
                } else if context.state.isWarmup {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.orange)
                } else if context.state.isRecap {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
                } else if context.state.isResting, let restEnd = context.state.restEndTimestamp {
                    let targetDate = Date(timeIntervalSince1970: restEnd)
                    ProgressView(timerInterval: Date()...max(Date().addingTimeInterval(1), targetDate), countsDown: true)
                        .progressViewStyle(.circular)
                        .tint(Color.orange)
                        .frame(width: 18, height: 18)
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: 0.75)
                            .stroke(Color.white, lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                        Text("S\(context.state.setIndex)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .frame(width: 20, height: 20)
                }
            }
            .keylineTint(Color.white)
        }
    }
}

// MARK: - Helper to strip auxiliary annotations from rep range string
private func cleanRepRange(_ text: String) -> String {
    if let parenIndex = text.firstIndex(of: "(") {
        return String(text[..<parenIndex]).trimmingCharacters(in: .whitespaces)
    }
    return text
}

private func compactRepRange(_ text: String) -> String {
    var cleaned = cleanRepRange(text)
    cleaned = cleaned.replacingOccurrences(of: "Reps", with: "", options: .caseInsensitive)
    cleaned = cleaned.replacingOccurrences(of: "Rep", with: "", options: .caseInsensitive)
    cleaned = cleaned.trimmingCharacters(in: .whitespaces)
    return cleaned.isEmpty ? text : cleaned
}

// MARK: - SCREEN-03.3: Rest Countdown HUD Expanded View (Wide Island Form)
struct RestCountdownExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 5) {
            // TOP ROW: Exercise Title + Rep Range Pill across wide island form
            HStack(alignment: .center, spacing: 6) {
                Text(state.exerciseName)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                // Dedicated Rep Range Pill
                HStack(spacing: 3) {
                    Image(systemName: "repeat")
                        .font(.system(size: 8, weight: .black))
                    Text(cleanRepRange(state.targetRepsText))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color(white: 0.16))
                .overlay(
                    Capsule().stroke(Color(white: 0.35), lineWidth: 0.8)
                )
                .clipShape(Capsule())
                .foregroundColor(.white)
            }
            .padding(.horizontal, 6)

            // MIDDLE ROW: Wide panoramic 4-pillar telemetry dashboard
            HStack(spacing: 4) {
                // Metric 1: Current Set
                VStack(spacing: 1) {
                    Text("SET")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("\(state.setIndex)/\(state.totalSets)")
                        .font(.system(size: 10.5, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Metric 2: Working Load
                VStack(spacing: 1) {
                    Text("LOAD")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(state.loadText)
                        .font(.system(size: 10.5, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Metric 3: Target Rep Window
                VStack(spacing: 1) {
                    Text("TARGET")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(cleanRepRange(state.targetRepsText))
                        .font(.system(size: 10.5, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Metric 4: Next Overload Target
                VStack(spacing: 1) {
                    Text("OVERLOAD")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(state.overloadIncrementText)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 6)

            // BOTTOM ROW: Interactive [-15s], [+30s], [Skip Rest ▶] Buttons
            HStack(spacing: 5) {
                Button(intent: AdjustTimerIntent(delta: -15)) {
                    Text("-15s")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(Color(white: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(intent: AdjustTimerIntent(delta: 30)) {
                    Text("+30s")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(Color(white: 0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(intent: SkipRestIntent()) {
                    HStack(spacing: 3) {
                        Text("Skip Rest")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        Image(systemName: "play.fill")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity * 1.3, minHeight: 26)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - SCREEN-03.4: Quick-Log Rep Outcome Triage Expanded View (Wide Island Form)
struct TriageExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 5) {
            // Header Row (Wide): Exercise name + Rep Range Pill + Set counter
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.exerciseName)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text("Set \(state.setIndex) of \(state.totalSets) Completed")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Color(white: 0.6))
                }

                Spacer(minLength: 4)

                // Rep Range Pill
                HStack(spacing: 3) {
                    Image(systemName: "repeat")
                        .font(.system(size: 8, weight: .black))
                    Text(cleanRepRange(state.targetRepsText))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color(white: 0.16))
                .overlay(
                    Capsule().stroke(Color(white: 0.35), lineWidth: 0.8)
                )
                .clipShape(Capsule())
                .foregroundColor(.white)
            }
            .padding(.horizontal, 6)

            // The 3 Triage Outcome Buttons (Wide Panoramic Spanning)
            HStack(spacing: 5) {
                // 1. Under Target (<8 Missed)
                Button(intent: LogTriageIntent(outcome: "missed")) {
                    VStack(spacing: 1.5) {
                        HStack(spacing: 2) {
                            Text("▼")
                                .font(.system(size: 7.5, weight: .bold))
                            Text(state.underTargetText)
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color(white: 0.85))

                        Text("Under Target")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(Color(white: 0.65))
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(Color(white: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color(white: 0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)

                // 2. Prescribed Reps (8-11 Target)
                Button(intent: LogTriageIntent(outcome: "target")) {
                    VStack(spacing: 1.5) {
                        HStack(spacing: 2) {
                            Text("🎯")
                                .font(.system(size: 8))
                            Text(state.prescribedTargetText)
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color.white)

                        Text("Prescribed Reps")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(Color(white: 0.8))
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(Color(white: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color(white: 0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)

                // 3. Overload (12+ Overload)
                Button(intent: LogTriageIntent(outcome: "overload")) {
                    VStack(spacing: 1.5) {
                        HStack(spacing: 2) {
                            Text("🚀")
                                .font(.system(size: 8))
                            Text(state.overloadTargetText)
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color.black)

                        Text(state.overloadIncrementText)
                            .font(.system(size: 7.5, weight: .heavy))
                            .foregroundColor(Color.black)
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            // Deep-link to full input modal in app
            Link(destination: URL(string: "overload://enter-exact")!) {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 8))
                    Text("Enter Exact Reps & Weight ›")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(Color(white: 0.7))
            }
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Warm-Up Expanded Dynamic Island View
struct WarmupExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 5) {
            // TOP ROW: Exercise Title + Warmup Set Pill
            HStack(spacing: 6) {
                Text(state.exerciseName)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("W\(state.warmupIndex) of \(state.totalWarmups)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color(white: 0.16))
                .overlay(
                    Capsule().stroke(Color.orange.opacity(0.6), lineWidth: 0.8)
                )
                .clipShape(Capsule())
                .foregroundColor(Color.orange)
            }
            .padding(.horizontal, 6)

            // MIDDLE ROW: Warm-up Target Card
            VStack(spacing: 2) {
                Text("PRESCRIBED WARM-UP RAMP")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(state.warmupTargetText.isEmpty ? "\(state.targetRepsText) @ \(state.loadText)" : state.warmupTargetText)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal, 6)

            // BOTTOM ROW: Actions
            if state.isResting {
                // If resting between warmups: Skip Rest button
                Button(intent: SkipRestIntent()) {
                    HStack(spacing: 6) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Ready for Warm-Up \(min(state.totalWarmups, state.warmupIndex + 1)) ›")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            } else {
                HStack(spacing: 6) {
                    // Complete Warmup button
                    Button(intent: LogWarmupIntent()) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9.5))
                            Text("Complete W\(state.warmupIndex) ✓")
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Skip Warmups button
                    Button(intent: SkipWarmupsIntent()) {
                        HStack(spacing: 4) {
                            Text("Skip to Set 1 ⏭")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(Color(white: 0.85))
                        .frame(width: 95)
                        .frame(height: 26)
                        .background(Color(white: 0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(white: 0.35), lineWidth: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
            }
        }
    }
}

// MARK: - Transition Rest Expanded Dynamic Island View
struct TransitionRestExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 5) {
            // TOP ROW: Up Next label & Next Exercise Title
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 8.5))
                    Text("UP NEXT")
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
                .foregroundColor(.white)

                Text(state.nextExerciseName.isEmpty ? state.exerciseName : state.nextExerciseName)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 6)

            // MIDDLE ROW: Inter-Exercise Rest Callout
            VStack(spacing: 1.5) {
                Text("INTER-EXERCISE RECOVERY REST")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Catch your breath & set up machine pins")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color(white: 0.8))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3.5)
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal, 6)

            // BOTTOM ROW: Skip Rest / Start Lift Button
            Button(intent: SkipRestIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("Ready to Start Lift ›")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
        }
    }
}

// MARK: - Progression Recap Expanded View (Screen showing logged sets & progression stats)
struct ProgressionRecapExpandedView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 5) {
            // TOP ROW: Exercise Title & Sets Logged Badge
            HStack(spacing: 6) {
                Text(state.exerciseName)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                // High-visibility Lift Complete pill
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("\(state.totalSets)/\(state.totalSets) Sets")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color(white: 0.16))
                .overlay(
                    Capsule().stroke(Color(white: 0.35), lineWidth: 0.8)
                )
                .clipShape(Capsule())
                .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
            }
            .padding(.horizontal, 6)

            // MIDDLE ROW: Panoramic Recap Cards (Logged Sets + Progression Outcome)
            HStack(spacing: 4) {
                // Sets Logged Card
                VStack(spacing: 1) {
                    Text("LOGGED SETS")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(state.recapLoggedSetsText.isEmpty ? "All Sets Complete" : state.recapLoggedSetsText)
                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3.5)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Progression Stat Card
                VStack(spacing: 1) {
                    Text("PROGRESSION")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(state.recapProgressionHeadline.isEmpty ? "Load Consolidated" : state.recapProgressionHeadline)
                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3.5)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 6)

            // BOTTOM ROW: High-contrast 1-Tap Advance Button
            Button(intent: ContinueNextExerciseIntent()) {
                HStack(spacing: 6) {
                    Text(state.recapIsFinalExercise ? "View Workout Summary 🏆" : "Continue to Next Lift")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                    Image(systemName: state.recapIsFinalExercise ? "trophy.fill" : "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
        }
    }
}

// MARK: - Lock Screen Banner View (iOS 16.1+ / 17+ with interactive controls)
struct LockScreenLiveActivityView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if state.isTransitionRest {
            VStack(spacing: 8) {
                // TOP ROW: Split Badge + Next Lift Pill + Countdown Timer
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(state.splitName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                            .foregroundColor(.white)

                        Text("TRANSITION REST")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(Color.orange)
                    }

                    Spacer(minLength: 4)

                    if let restEnd = state.restEndTimestamp {
                        let targetDate = Date(timeIntervalSince1970: restEnd)
                        Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .shadow(color: Color.orange.opacity(0.4), radius: 3)
                    }
                }

                // MIDDLE: Next Exercise Teaser Card
                VStack(spacing: 3) {
                    Text("UP NEXT IN ROUTINE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(state.nextExerciseName.isEmpty ? state.exerciseName : state.nextExerciseName)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // BOTTOM: Skip Rest Button
                Button(intent: SkipRestIntent()) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .black))
                        Text("Ready to Start Lift Now ›")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        } else if state.isWarmup {
            VStack(spacing: 8) {
                // TOP ROW: Split Badge + Exercise Name + Warmup Pill
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(state.splitName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                            .foregroundColor(.white)

                        Text(state.exerciseName)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("W\(state.warmupIndex)/\(state.totalWarmups)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color(white: 0.16))
                    .overlay(
                        Capsule().stroke(Color.orange.opacity(0.6), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .foregroundColor(Color.orange)
                }

                // MIDDLE: Prescribed Target Card or Countdown
                if state.isResting, let restEnd = state.restEndTimestamp {
                    let targetDate = Date(timeIntervalSince1970: restEnd)
                    VStack(spacing: 2) {
                        Text("WARM-UP REST INTERVAL")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .shadow(color: Color.orange.opacity(0.4), radius: 3)
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button(intent: SkipRestIntent()) {
                        HStack(spacing: 6) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 11, weight: .black))
                            Text("Ready for Warm-Up \(min(state.totalWarmups, state.warmupIndex + 1)) ›")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 3) {
                        Text("PRESCRIBED WARM-UP RAMP")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(state.warmupTargetText.isEmpty ? "\(state.targetRepsText) @ \(state.loadText)" : state.warmupTargetText)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    HStack(spacing: 8) {
                        Button(intent: LogWarmupIntent()) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .black))
                                Text("Complete Warm-Up \(state.warmupIndex) ✓")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(intent: SkipWarmupsIntent()) {
                            Text("Skip ⏭")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(white: 0.85))
                                .frame(width: 80, height: 36)
                                .background(Color(white: 0.16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color(white: 0.35), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        } else if state.isRecap {
            VStack(spacing: 8) {
                // TOP ROW: Split Badge + Exercise Name + Completion Pill
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(state.splitName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                            .foregroundColor(.white)

                        Text(state.exerciseName)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 4)

                    // Completion Pill
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("\(state.totalSets)/\(state.totalSets) Sets")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(white: 0.16))
                    .overlay(
                        Capsule().stroke(Color(white: 0.35), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
                }

                // MIDDLE: 2 Wide Telemetry Cards (Logged Sets + Progression Stat)
                HStack(spacing: 6) {
                    VStack(alignment: .center, spacing: 2) {
                        Text("SETS LOGGED")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(state.recapLoggedSetsText.isEmpty ? "All Sets Complete" : state.recapLoggedSetsText)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .center, spacing: 2) {
                        Text("PROGRESSION")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(state.recapProgressionHeadline.isEmpty ? "Load Consolidated" : state.recapProgressionHeadline)
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 0.25, green: 0.85, blue: 0.65))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // BOTTOM: 1-Tap Advance Button
                Button(intent: ContinueNextExerciseIntent()) {
                    HStack(spacing: 6) {
                        Text(state.recapIsFinalExercise ? "View Workout Summary 🏆" : "Continue to Next Lift")
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                        Image(systemName: state.recapIsFinalExercise ? "trophy.fill" : "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        } else {
            VStack(spacing: 9) {
                // TOP ROW: Split Badge + Exercise Name on left, Rep Range Pill on right
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Text(state.splitName)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .foregroundColor(.white)

                    Text(state.exerciseName)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 4)

                // High-visibility Rep Range Pill
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.system(size: 9, weight: .black))
                    Text(cleanRepRange(state.targetRepsText))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color(white: 0.16))
                .overlay(
                    Capsule().stroke(Color(white: 0.35), lineWidth: 1)
                )
                .clipShape(Capsule())
                .foregroundColor(.white)
            }

            // MIDDLE ROW: Panoramic 4-pillar telemetry dashboard
            HStack(spacing: 6) {
                // Metric 1: Current Set
                VStack(spacing: 2) {
                    Text("SET")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                    Text("\(state.setIndex)/\(state.totalSets)")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Metric 2: Working Load
                VStack(spacing: 2) {
                    Text("LOAD")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                    Text(state.loadText)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Metric 3: Target Window
                VStack(spacing: 2) {
                    Text("TARGET")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                    Text(cleanRepRange(state.targetRepsText))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Metric 4: Timer / Next Progression Status
                VStack(spacing: 2) {
                    if state.isResting, let restEnd = state.restEndTimestamp {
                        let targetDate = Date(timeIntervalSince1970: restEnd)
                        Text("REST")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.orange.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(timerInterval: Date()...max(Date(), targetDate), countsDown: true)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(Color.orange)
                            .shadow(color: Color.orange.opacity(0.4), radius: 3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if state.isTriageLogging {
                        Text("TRIAGE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("LOG S\(state.setIndex)")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("OVERLOAD")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(state.overloadIncrementText)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // BOTTOM ROW: Dynamic Interactive Action Buttons
            if state.isResting {
                HStack(spacing: 8) {
                    Button(intent: AdjustTimerIntent(delta: -15)) {
                        Text("-15s")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Color(white: 0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(intent: AdjustTimerIntent(delta: 30)) {
                        Text("+30s")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Color(white: 0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(intent: SkipRestIntent()) {
                        HStack(spacing: 4) {
                            Text("Skip Rest")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity * 1.3, minHeight: 36)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else if state.isTriageLogging {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Button(intent: LogTriageIntent(outcome: "missed")) {
                            VStack(spacing: 1) {
                                HStack(spacing: 2) {
                                    Text("▼")
                                        .font(.system(size: 8, weight: .bold))
                                    Text(state.underTargetText)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(Color(white: 0.85))

                                Text("Under Target")
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundColor(Color(white: 0.65))
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color(white: 0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(white: 0.25), lineWidth: 1.2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(intent: LogTriageIntent(outcome: "target")) {
                            VStack(spacing: 1) {
                                HStack(spacing: 2) {
                                    Text("🎯")
                                        .font(.system(size: 9))
                                    Text(state.prescribedTargetText)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(Color.white)

                                Text("Prescribed")
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundColor(Color(white: 0.8))
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color(white: 0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(white: 0.35), lineWidth: 1.2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(intent: LogTriageIntent(outcome: "overload")) {
                            VStack(spacing: 1) {
                                HStack(spacing: 2) {
                                    Text("🚀")
                                        .font(.system(size: 9))
                                    Text(state.overloadTargetText)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(Color.black)

                                Text(state.overloadIncrementText)
                                    .font(.system(size: 8.5, weight: .heavy))
                                    .foregroundColor(Color.black)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white, lineWidth: 1.2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Link(destination: URL(string: "overload://enter-exact")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 9))
                            Text("Enter Exact Reps & Weight ›")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Color(white: 0.7))
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Button(intent: SkipRestIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Log Set \(state.setIndex) Outcome")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Link(destination: URL(string: "overload://enter-exact")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 9))
                            Text("Exact")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Color(white: 0.8))
                        .frame(width: 80, height: 36)
                        .background(Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
    }
}
}
