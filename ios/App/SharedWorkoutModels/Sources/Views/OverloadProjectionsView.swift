import SwiftUI
import Charts

public struct ProjectionDataPoint: Identifiable, Hashable {
    public var id = UUID()
    public var week: Int
    public var seriesName: String
    public var weight: Double
    public var e1RM: Double
}

public struct OverloadProjectionsView: View {
    @ObservedObject var manager: WorkoutSessionManager

    @State private var selectedHorizon: Int = 8 // 8 or 12 weeks
    @State private var selectedExerciseId: String = ""
    @State private var targetGoalWeight: Double = 100.0
    @State private var weeklyFrequency: Int = 2 // 1 or 2 workouts per week
    @State private var adherenceRate: Double = 0.90 // 90% adherence
    @State private var scrubbedWeek: Int? = nil

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    private var selectedExercise: Exercise? {
        if let found = manager.exercises.first(where: { $0.id == selectedExerciseId }) {
            return found
        }
        return manager.exercises.first
    }

    private var chartData: [ProjectionDataPoint] {
        guard let ex = selectedExercise else { return [] }
        var points: [ProjectionDataPoint] = []

        let startingW1 = ex.loads.first ?? ex.weight
        let startingW2 = ex.loads.indices.contains(1) ? ex.loads[1] : startingW1 * 0.8
        let startingW3 = ex.loads.indices.contains(2) ? ex.loads[2] : startingW1 * 0.6
        let startingE1RM = ex.e1RM > 0 ? ex.e1RM : startingW1 * 1.33
        let step = ex.microIncrement

        var currentW1 = startingW1
        var currentW2 = startingW2
        var currentW3 = startingW3
        var currentE1RM = startingE1RM

        let totalWeeks = selectedHorizon

        for w in 0...totalWeeks {
            points.append(ProjectionDataPoint(week: w, seriesName: "Anchor (W1)", weight: currentW1, e1RM: currentE1RM))
            points.append(ProjectionDataPoint(week: w, seriesName: "Intermediate (W2)", weight: currentW2, e1RM: currentE1RM))
            points.append(ProjectionDataPoint(week: w, seriesName: "Base (W3)", weight: currentW3, e1RM: currentE1RM))

            // Simulate weekly progression step
            let promotionChance = (Double(weeklyFrequency) * 0.5) * adherenceRate
            if w > 0 && Double.random(in: 0...1) < promotionChance {
                currentW3 += step
                if currentW3 >= currentW2 { currentW2 += step }
                if currentW2 >= currentW1 * 0.85 { currentW1 += step }
                currentE1RM = currentW1 * 1.33
            } else if w > 0 {
                // Consolidation micro-gain
                currentW1 += (step * 0.25 * Double(weeklyFrequency) * adherenceRate)
                currentW2 = max(currentW2, currentW1 * 0.80)
                currentW3 = max(currentW3, currentW1 * 0.60)
                currentE1RM = currentW1 * 1.33
            }
        }
        return points
    }

    private var estimatedWeeksToGoal: Int? {
        guard let ex = selectedExercise else { return nil }
        let currentW1 = ex.loads.first ?? ex.weight
        if currentW1 >= targetGoalWeight { return 0 }
        let remaining = targetGoalWeight - currentW1
        let weeklyGain = (ex.microIncrement * Double(weeklyFrequency) * 0.4) * adherenceRate
        guard weeklyGain > 0 else { return nil }
        return max(1, Int((remaining / weeklyGain).rounded(.up)))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Exercise Picker & Horizon Toggle
                    topControlsBar

                    // Swift Charts Card
                    chartCard

                    // Interactive Scrubbed Inspector
                    if let scrubbed = scrubbedWeek {
                        scrubInspectorCard(week: scrubbed)
                    }

                    // Target Milestone Predictor
                    targetGoalCard

                    // Scenario Simulation Sliders
                    scenarioParametersCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Overload Projections")
            .onAppear {
                if selectedExerciseId.isEmpty, let first = manager.exercises.first {
                    selectedExerciseId = first.id
                    targetGoalWeight = (first.loads.first ?? first.weight) + 20.0
                }
            }
        }
    }

    // MARK: - Subviews

    private var topControlsBar: some View {
        VStack(spacing: 10) {
            // Exercise Picker
            Menu {
                ForEach(manager.exercises) { ex in
                    Button(action: {
                        Theme.hapticImpact(.light)
                        selectedExerciseId = ex.id
                        targetGoalWeight = (ex.loads.first ?? ex.weight) + 20.0
                    }) {
                        HStack {
                            Text(ex.name)
                            if ex.id == selectedExerciseId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACTIVE PROJECTION LIFT")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(Theme.emerald)
                        Text(selectedExercise?.name ?? "Select Exercise")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(14)
                .background(Theme.surfaceCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }

            // Dual Horizon Picker
            HStack(spacing: 8) {
                horizonButton(weeks: 8, label: "8-Week Horizon")
                horizonButton(weeks: 12, label: "12-Week Horizon")
            }
        }
    }

    private func horizonButton(weeks: Int, label: String) -> some View {
        Button(action: {
            Theme.hapticImpact(.light)
            selectedHorizon = weeks
        }) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(selectedHorizon == weeks ? .black : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selectedHorizon == weeks ? Theme.emerald : Theme.surfaceElevated)
                .cornerRadius(10)
        }
    }

    // MARK: - Swift Charts Card
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Hypertrophy Forecast Curve", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("SWIFT CHARTS 120Hz")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Theme.emerald)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.emerald.opacity(0.15))
                    .cornerRadius(4)
            }

            // Chart Rendering
            Chart {
                ForEach(chartData) { point in
                    LineMark(
                        x: .value("Week", point.week),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(by: .value("Series", point.seriesName))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: point.seriesName == "Anchor (W1)" ? 3 : 2))

                    PointMark(
                        x: .value("Week", point.week),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(by: .value("Series", point.seriesName))
                    .symbolSize(point.seriesName == "Anchor (W1)" ? 25 : 15)
                }

                // Target Goal Rule
                RuleMark(y: .value("Target Goal", targetGoalWeight))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Theme.amber)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target \(String(format: "%.0f", targetGoalWeight))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.amber)
                            .padding(3)
                            .background(Theme.surfaceElevated)
                            .cornerRadius(4)
                    }

                // Interactive Scrub Cursor
                if let scrub = scrubbedWeek {
                    RuleMark(x: .value("Week", scrub))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .chartForegroundStyleScale([
                "Anchor (W1)": Theme.emerald,
                "Intermediate (W2)": Theme.cyan,
                "Base (W3)": Theme.amber
            ])
            .chartXScale(domain: 0...selectedHorizon)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel() {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: selectedHorizon)) { value in
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel() {
                        if let v = value.as(Int.self) {
                            Text("W\(v)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    let x = val.location.x
                                    if let week: Int = proxy.value(atX: x) {
                                        scrubbedWeek = min(selectedHorizon, max(0, week))
                                        Theme.hapticTick()
                                    }
                                }
                                .onEnded { _ in
                                    // Keep or clear scrub cursor
                                }
                        )
                }
            }
            .frame(height: 220)
            .padding(.vertical, 4)

            // Legend
            HStack(spacing: 12) {
                legendItem(color: Theme.emerald, label: "W1 Anchor")
                legendItem(color: Theme.cyan, label: "W2 Intermediate")
                legendItem(color: Theme.amber, label: "W3 Base")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Scrub Inspector
    private func scrubInspectorCard(week: Int) -> some View {
        let wPoints = chartData.filter { $0.week == week }
        let w1 = wPoints.first(where: { $0.seriesName == "Anchor (W1)" })?.weight ?? 0
        let w2 = wPoints.first(where: { $0.seriesName == "Intermediate (W2)" })?.weight ?? 0
        let w3 = wPoints.first(where: { $0.seriesName == "Base (W3)" })?.weight ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WEEK \(week) FORECAST TELEMETRY")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(Theme.emerald)
                Spacer()
                Button(action: { scrubbedWeek = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textMuted)
                }
            }

            HStack(spacing: 12) {
                metricBox(label: "Anchor (W1)", value: String(format: "%.1f", w1), color: Theme.emerald)
                metricBox(label: "Intermediate (W2)", value: String(format: "%.1f", w2), color: Theme.cyan)
                metricBox(label: "Base (W3)", value: String(format: "%.1f", w3), color: Theme.amber)
            }
        }
        .padding(14)
        .background(Theme.surfaceElevated)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.emerald.opacity(0.5), lineWidth: 1))
    }

    private func metricBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.surfaceCard)
        .cornerRadius(8)
    }

    // MARK: - Target Goal Milestone
    private var targetGoalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Target Goal Milestone", systemImage: "flag.checkered")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.amber)
                Spacer()
                if let weeks = estimatedWeeksToGoal {
                    Text(weeks == 0 ? "GOAL REACHED!" : "~ \(weeks) WEEKS")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Theme.emerald)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.emerald.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            HStack {
                Text("Target Load (\(selectedExercise?.unit.uppercased() ?? "KG"))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Stepper("\(String(format: "%.1f", targetGoalWeight))", value: $targetGoalWeight, in: 20...400, step: selectedExercise?.microIncrement ?? 2.5)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(12)
            .background(Theme.surfaceElevated)
            .cornerRadius(10)
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Scenario Sliders
    private var scenarioParametersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Scenario Simulation Sandbox", systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            VStack(spacing: 12) {
                // Weekly Frequency
                HStack {
                    Text("Weekly Frequency")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Picker("Frequency", selection: $weeklyFrequency) {
                        Text("1x / Week").tag(1)
                        Text("2x / Week").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }

                Divider().background(Theme.border)

                // Adherence
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Session Adherence Rate")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(adherenceRate * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.emerald)
                    }
                    Slider(value: $adherenceRate, in: 0.5...1.0, step: 0.05)
                        .accentColor(Theme.emerald)
                }
            }
            .padding(14)
            .background(Theme.surfaceElevated)
            .cornerRadius(12)
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
