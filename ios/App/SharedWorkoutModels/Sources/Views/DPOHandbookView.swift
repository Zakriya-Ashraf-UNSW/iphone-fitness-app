import SwiftUI

public struct DPOHandbookView: View {
    @State private var selectedCategory: RuleCategory = .all
    @State private var searchQuery: String = ""

    // Interactive Sandbox Simulator State
    @State private var simW1: Double = 80.0
    @State private var simW2: Double = 67.5
    @State private var simW3: Double = 52.5
    @State private var simStep: Double = 2.5
    @State private var simR1: Int = 10
    @State private var simR2: Int = 10
    @State private var simR3: Int = 10
    @State private var simRmin: Int = 8
    @State private var simRmax: Int = 10
    @State private var simActiveSets: Int = 3
    @State private var simResult: ProgressionOutcome? = nil

    public enum RuleCategory: String, CaseIterable, Identifiable {
        case all = "ALL SECTIONS"
        case simulator = "LIVE SANDBOX"
        case invariants = "INVARIANTS"
        case progression = "PROGRESSION"
        case calibration = "CALIBRATION"
        case dynamicRest = "DYNAMIC REST"
        case glossary = "GLOSSARY"

        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Category Picker
                    categoryPills

                    if selectedCategory == .simulator {
                        interactiveSimulatorSection
                    } else {
                        // Search bar
                        searchBar

                        // Handbook Sections
                        VStack(spacing: 14) {
                            if matchesFilter(cat: .invariants, title: "1. Beginner 101 — Core Concept") {
                                sectionCard(
                                    title: "1. Beginner 101 — Core Concept",
                                    badge: "PHILOSOPHY",
                                    badgeColor: Theme.emerald,
                                    summary: "Zero-subjectivity progressive overload. No guessing RPE or bar velocity. The DPO engine deterministically prescribes loads, reps, and rest intervals purely from objective rep performance to muscular failure (0 RIR)."
                                )
                            }

                            if matchesFilter(cat: .invariants, title: "2. The 3-Set Cascade & Invariants") {
                                sectionCard(
                                    title: "2. The 3-Set Cascade & Invariants",
                                    badge: "MATHEMATICAL INVARIANTS",
                                    badgeColor: Theme.purple,
                                    summary: "Every exercise maintains 3 structured tiers:\n• W1 (Anchor Set): Primary hypertrophy stimulus\n• W2 (Intermediate Set): Floor ≥ 80% of W1\n• W3 (Base Overload): Floor ≥ 60% of W1\nInvariant Rule: W1 ≥ W2 ≥ W3 strictly enforced at all times."
                                )
                            }

                            if matchesFilter(cat: .calibration, title: "3. Calibration, e1RM & Fatigue Index") {
                                sectionCard(
                                    title: "3. Calibration, e1RM & Fatigue Index",
                                    badge: "PHYSIOLOGY",
                                    badgeColor: Theme.sky,
                                    summary: "Measured via a 2-set protocol with 180s rest:\n• e1RM = W × (1 + R / 30)\n• Expected Set 2 reps = 30 × ((e1RM / W2) - 1)\n• Fatigue Index (FI) = clamp(1 - R2 / R2_expected, 0.0, 1.0)\nHigh FI triggers wider load drops to preserve volume."
                                )
                            }

                            if matchesFilter(cat: .progression, title: "4. Progression Engine & Consolidation Gates") {
                                sectionCard(
                                    title: "4. Progression Engine & Consolidation Gates",
                                    badge: "DECISION LOGIC",
                                    badgeColor: Theme.amber,
                                    summary: "Bottom-Up Consolidation:\n1. Set 3 promotes first when R3 ≥ R_max.\n2. Set 2 promotes second when R2 ≥ R_max.\n3. Set 1 (Anchor) requires foundational consolidation:\n   Gate 1: W2 ≥ 85% of W1\n   Gate 2: W3 ≥ 65% of W1\nOnly when both gates pass does Anchor load increase."
                                )
                            }

                            if matchesFilter(cat: .dynamicRest, title: "5. Dynamic Rest & 2-Set Re-Entry") {
                                sectionCard(
                                    title: "5. Dynamic Rest & 2-Set Re-Entry",
                                    badge: "VOLUME ADAPTATION",
                                    badgeColor: Theme.cyan,
                                    summary: "When Set 3 breaches the 60% floor for 2 consecutive sessions, the exercise automatically compresses to 2-Set Mode.\n\nRe-Entry Gate: Requires 2 consecutive sessions where Set 2 reaches ≥ 85% of Set 1, fatigue drop ≤ 2 reps, and rep ceiling is cleared. Re-enters at a soft 65% anchor load."
                                )
                            }

                            if matchesFilter(cat: .calibration, title: "6. 5-Session Periodic Recalibration") {
                                sectionCard(
                                    title: "6. 5-Session Periodic Recalibration",
                                    badge: "NEURAL DRIFT CHECK",
                                    badgeColor: Theme.rose,
                                    summary: "Every 5 sessions, Set 1 performance is compared against predicted reps:\n• Δ = Actual Reps - Predicted Reps\n• Δ ≥ +2: SUPERCOMPENSATION (e1RM elevated)\n• Δ ≤ -2: FATIGUE FLAG (potential overtraining)\n• Otherwise: VERIFIED"
                                )
                            }

                            if matchesFilter(cat: .glossary, title: "7. Beginner Glossary & Decoder") {
                                sectionCard(
                                    title: "7. Beginner Glossary & Decoder",
                                    badge: "TERMINOLOGY",
                                    badgeColor: Theme.textSecondary,
                                    summary: "• 0 RIR: Muscular failure where another rep is impossible.\n• Micro-increment (S): The smallest plate/pin step (e.g. 1.25kg, 2.5kg, 5lbs).\n• Anchor Load (W1): The maximum working resistance.\n• Consolidation: Ensuring secondary sets keep pace before advancing primary load."
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("DPO Handbook")
        }
    }

    // MARK: - Subviews

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RuleCategory.allCases) { cat in
                    Button(action: {
                        Theme.hapticImpact(.light)
                        selectedCategory = cat
                    }) {
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(selectedCategory == cat ? .black : Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedCategory == cat ? Theme.emerald : Theme.surfaceElevated)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textMuted)
            TextField("Search handbook rules or formulas...", text: $searchQuery)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding(10)
        .background(Theme.surfaceElevated)
        .cornerRadius(10)
    }

    private func sectionCard(title: String, badge: String, badgeColor: Color, summary: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15))
                    .cornerRadius(4)
            }

            Text(summary)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func matchesFilter(cat: RuleCategory, title: String) -> Bool {
        if selectedCategory != .all && selectedCategory != cat { return false }
        if !searchQuery.isEmpty && !title.localizedCaseInsensitiveContains(searchQuery) { return false }
        return true
    }

    // MARK: - Interactive Simulator Sandbox
    private var interactiveSimulatorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DPO Engine Interactive Simulator")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(Theme.emerald)
                Text("Test arbitrary loads and reps against SPEC-001 consolidation gates in real-time.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            // Input Parameters
            VStack(spacing: 12) {
                HStack {
                    Text("Anchor Load (W1)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Stepper("\(String(format: "%.1f", simW1)) kg", value: $simW1, in: 10...300, step: simStep)
                        .foregroundColor(Theme.textPrimary)
                }
                HStack {
                    Text("Intermediate (W2)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Stepper("\(String(format: "%.1f", simW2)) kg", value: $simW2, in: 10...300, step: simStep)
                        .foregroundColor(Theme.textPrimary)
                }
                HStack {
                    Text("Base Overload (W3)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Stepper("\(String(format: "%.1f", simW3)) kg", value: $simW3, in: 10...300, step: simStep)
                        .foregroundColor(Theme.textPrimary)
                }

                Divider().background(Theme.border)

                HStack {
                    Text("Set 1 Reps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Stepper("\(simR1) reps", value: $simR1, in: 1...30)
                        .foregroundColor(Theme.textPrimary)
                }
                HStack {
                    Text("Set 2 Reps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Stepper("\(simR2) reps", value: $simR2, in: 1...30)
                        .foregroundColor(Theme.textPrimary)
                }
                HStack {
                    Text("Set 3 Reps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Stepper("\(simR3) reps", value: $simR3, in: 1...30)
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .padding(16)
            .background(Theme.surfaceElevated)
            .cornerRadius(14)

            Button(action: {
                runSimulation()
                Theme.hapticSuccess()
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Evaluate Progression Engine")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.emerald)
                .cornerRadius(12)
            }

            // Results Card
            if let result = simResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SIMULATION OUTCOME")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Theme.emerald)

                    Text(result.summary)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Divider().background(Theme.border)

                    HStack(spacing: 12) {
                        simBadge(label: "S1 Adv", active: result.s1Adv)
                        simBadge(label: "S2 Adv", active: result.s2Adv)
                        simBadge(label: "S3 Adv", active: result.s3Adv)
                    }

                    if let reason = result.s1HeldReason {
                        Text("Hold Reason: \(reason)")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.amber)
                    }

                    HStack {
                        Text("Next Loads: [\(String(format: "%.1f", result.loads[0])), \(String(format: "%.1f", result.loads[1])), \(String(format: "%.1f", result.loads[2]))]")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(Theme.sky)
                    }
                }
                .padding(16)
                .background(Theme.surfaceCard)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.emerald, lineWidth: 1.5))
            }
        }
    }

    private func simBadge(label: String, active: Bool) -> some View {
        Text("\(label): \(active ? "YES" : "NO")")
            .font(.system(size: 11, weight: .black))
            .foregroundColor(active ? Theme.emerald : Theme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? Theme.emerald.opacity(0.15) : Theme.surfaceElevated)
            .cornerRadius(6)
    }

    private func runSimulation() {
        let loads = [simW1, simW2, simW3]
        let reps = [simR1, simR2, simR3]
        simResult = DPOEngine.evaluateProgression(
            loads: loads,
            reps: reps,
            activeSetsCount: simActiveSets,
            repMax: simRmax,
            microIncrement: simStep
        )
    }
}
