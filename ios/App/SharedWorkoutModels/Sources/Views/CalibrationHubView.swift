import SwiftUI

public struct CalibrationHubView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @State private var selectedFilter: CalibrationFilter = .all
    @State private var exerciseToCalibrate: Exercise? = nil
    @State private var showResetConfirm: Bool = false
    @State private var exerciseToReset: Exercise? = nil

    public enum CalibrationFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case calibrated = "CALIBRATED"
        case uncalibrated = "PENDING"
        case recalibrationDue = "DUE (5+)"

        public var id: String { rawValue }
    }

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    private var filteredExercises: [Exercise] {
        manager.exercises.filter { ex in
            switch selectedFilter {
            case .all:
                return true
            case .calibrated:
                return ex.isCalibrated
            case .uncalibrated:
                return !ex.isCalibrated
            case .recalibrationDue:
                return ex.sessionsSinceRecalibration >= 5
            }
        }
    }

    private var totalCount: Int { manager.exercises.count }
    private var calibratedCount: Int { manager.exercises.filter { $0.isCalibrated }.count }
    private var dueCount: Int { manager.exercises.filter { $0.sessionsSinceRecalibration >= 5 }.count }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Top Overview Metrics
                    metricsOverviewCard

                    // Filter Pills
                    filterPills

                    // Exercise Calibration Cards
                    if filteredExercises.isEmpty {
                        emptyStateCard
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredExercises) { exercise in
                                calibrationExerciseRow(exercise)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Calibration Hub")
            .sheet(item: $exerciseToCalibrate) { exercise in
                CalibrationRunnerView(manager: manager, exercise: exercise)
            }
            .confirmationDialog(
                "Reset Calibration?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                if let ex = exerciseToReset {
                    Button("Reset \(ex.name)", role: .destructive) {
                        manager.resetExerciseCalibration(id: ex.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This resets the calculated e1RM and Fatigue Index to uncalibrated defaults.")
            }
        }
    }

    // MARK: - Subviews

    private var metricsOverviewCard: some View {
        HStack(spacing: 10) {
            statBox(label: "TOTAL LIFTS", value: "\(totalCount)", color: Theme.textPrimary)
            statBox(label: "CALIBRATED", value: "\(calibratedCount)", color: Theme.emerald)
            statBox(label: "DUE (5+ SESS)", value: "\(dueCount)", color: dueCount > 0 ? Theme.amber : Theme.textMuted)
        }
        .padding(12)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
        .cornerRadius(10)
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CalibrationFilter.allCases) { filter in
                    Button(action: {
                        Theme.hapticImpact(.light)
                        selectedFilter = filter
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(selectedFilter == filter ? .black : Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Theme.emerald : Theme.surfaceElevated)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func calibrationExerciseRow(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title & Status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 6) {
                        Text(exercise.split)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.emerald)
                        Text("•")
                            .foregroundColor(Theme.textMuted)
                        Text(exercise.category.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()

                // Status Badge
                statusBadge(exercise)
            }

            Divider().background(Theme.border)

            // Metrics Row
            HStack(spacing: 12) {
                metricColumn(label: "e1RM", value: exercise.isCalibrated ? String(format: "%.1f %@", exercise.e1RM, exercise.unit) : "—")
                metricColumn(label: "Fatigue (FI)", value: exercise.isCalibrated ? String(format: "%.3f", exercise.fatigueIndex) : "—")
                metricColumn(label: "Recalib Count", value: "\(exercise.sessionsSinceRecalibration) / 5 sess")
            }

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: {
                    Theme.hapticImpact(.medium)
                    exerciseToCalibrate = exercise
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: exercise.isCalibrated ? "arrow.triangle.2.circlepath" : "bolt.badge.clock.fill")
                        Text(exercise.isCalibrated ? "Recalibrate (2-Set)" : "Calibrate Lift")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(exercise.sessionsSinceRecalibration >= 5 ? Theme.amber : Theme.emerald)
                    .cornerRadius(10)
                }

                if exercise.isCalibrated {
                    Button(action: {
                        exerciseToReset = exercise
                        showResetConfirm = true
                        Theme.hapticImpact(.light)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                            .frame(width: 40, height: 40)
                            .background(Theme.surfaceElevated)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(exercise.sessionsSinceRecalibration >= 5 ? Theme.amber.opacity(0.6) : Theme.border, lineWidth: 1)
        )
    }

    private func statusBadge(_ exercise: Exercise) -> some View {
        Group {
            if exercise.sessionsSinceRecalibration >= 5 {
                Text("RECALIB DUE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.amber.opacity(0.15))
                    .cornerRadius(6)
            } else if exercise.isCalibrated {
                Text("CALIBRATED")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.emerald)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.emerald.opacity(0.15))
                    .cornerRadius(6)
            } else {
                Text("UNCALIBRATED")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(6)
            }
        }
    }

    private func metricColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(Theme.textMuted)
            Text("No exercises match filter.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
