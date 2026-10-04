import SwiftUI

public struct WorkingChamberView: View {
    @ObservedObject var manager: WorkoutSessionManager
    let setNumber: Int

    public init(manager: WorkoutSessionManager, setNumber: Int) {
        self.manager = manager
        self.setNumber = setNumber
    }

    private var currentLoad: Double {
        guard let ex = manager.currentExercise else { return 0 }
        let idx = setNumber - 1
        return ex.loads.indices.contains(idx) ? ex.loads[idx] : ex.weight
    }

    private var outcome: String? {
        switch setNumber {
        case 1: return manager.s1Outcome
        case 2: return manager.s2Outcome
        default: return manager.s3Outcome
        }
    }

    private var verdict: String? {
        switch setNumber {
        case 1: return manager.s1Verdict
        case 2: return manager.s2Verdict
        default: return manager.s3Verdict
        }
    }

    private var setTitle: String {
        switch setNumber {
        case 1: return "SET 1: ANCHOR DRIVER"
        case 2: return "SET 2: INTERMEDIATE SET"
        default: return "SET 3: BASE HYPERTROPHY"
        }
    }

    private var setAccentColor: Color {
        switch setNumber {
        case 1: return Theme.emerald
        case 2: return Theme.sky
        default: return Theme.purple
        }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(setTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(setAccentColor)
                        .tracking(1.0)
                    Text("Working Set \(setNumber) of \(manager.currentExercise?.activeSetsCount ?? 3)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
            }

            // Prescribed Load & Reps
            if let ex = manager.currentExercise {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PRESCRIBED LOAD")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                            .tracking(0.5)
                        Text(String(format: "%.1f %@", currentLoad, ex.unit.uppercased()))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Divider()
                        .frame(height: 36)
                        .background(Theme.border)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("TARGET REPS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                            .tracking(0.5)
                        Text("\(ex.repWindowMin)–\(ex.repWindowMax) reps")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Theme.surfaceCard)
                .cornerRadius(12)
            }

            // 1-Tap Triage Buttons
            if let ex = manager.currentExercise {
                VStack(spacing: 10) {
                    Text("TAP OUTCOME TO LOG & AUTO-START REST")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                        .tracking(0.8)

                    HStack(spacing: 10) {
                        // Under Target
                        triageButton(
                            title: "< \(ex.repWindowMin) Missed",
                            subtitle: "Under Target",
                            color: Theme.crimson,
                            isSelected: outcome == "missed"
                        ) {
                            logOutcome("missed")
                        }

                        // Prescribed Target
                        triageButton(
                            title: "\(ex.repWindowMin)–\(ex.repWindowMax) Target",
                            subtitle: "Solid In Window",
                            color: Theme.emerald,
                            isSelected: outcome == "target"
                        ) {
                            logOutcome("target")
                        }

                        // Overload
                        triageButton(
                            title: "\(ex.repWindowMax + 1)+ Overload",
                            subtitle: "+\(ex.microIncrement) \(ex.unit) Next",
                            color: Theme.purple,
                            isSelected: outcome == "overload"
                        ) {
                            logOutcome("overload")
                        }
                    }
                }
            }

            // Verdict Box
            if let v = verdict {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(setAccentColor)
                        .font(.system(size: 16))
                    Text(v)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(nil)
                    Spacer()
                }
                .padding(14)
                .background(setAccentColor.opacity(0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(setAccentColor.opacity(0.3), lineWidth: 1)
                )
            }

            // Advance Navigation Button
            if outcome != nil {
                if setNumber == 1 {
                    Button(action: { manager.goToSet(2) }) {
                        HStack {
                            Spacer()
                            Text("Next: Set 2 (Intermediate) →")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(Theme.sky)
                        .cornerRadius(12)
                    }
                } else if setNumber == 2 {
                    if (manager.currentExercise?.activeSetsCount ?? 3) > 2 {
                        Button(action: { manager.goToSet(3) }) {
                            HStack {
                                Spacer()
                                Text("Next: Set 3 (Base) →")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .background(Theme.purple)
                            .cornerRadius(12)
                        }
                    } else {
                        finishButton
                    }
                } else {
                    finishButton
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

    private var finishButton: some View {
        Button(action: { manager.commitCurrentExercise() }) {
            HStack {
                Spacer()
                Text("Save, Log & Next Lift →")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(Theme.emerald)
            .cornerRadius(12)
        }
    }

    private func logOutcome(_ o: String) {
        switch setNumber {
        case 1: manager.logSet1(outcome: o)
        case 2: manager.logSet2(outcome: o)
        default: manager.logSet3(outcome: o)
        }
    }

    private func triageButton(title: String, subtitle: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .black : Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .black.opacity(0.8) : Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(isSelected ? color : Theme.surfaceCard)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}
