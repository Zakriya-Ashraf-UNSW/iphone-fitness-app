import SwiftUI

public struct WorkoutHistoryView: View {
    @State private var history: [WorkoutHistoryEntry] = []
    @State private var selectedSplit: String = "ALL"
    @State private var showClearConfirm: Bool = false

    public init() {}

    private var filteredHistory: [WorkoutHistoryEntry] {
        if selectedSplit == "ALL" { return history }
        return history.filter { $0.split.uppercased() == selectedSplit.uppercased() }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary Stats Card
                    summaryStatsCard

                    // Split Filter Pills
                    splitFilterPills

                    // History Entries
                    if filteredHistory.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredHistory) { entry in
                                historyCard(entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Workout Archive")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !history.isEmpty {
                        Button(action: { showClearConfirm = true }) {
                            Text("Clear")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.crimson)
                        }
                    }
                }
            }
            .confirmationDialog("Clear All History?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear Workout History", role: .destructive) {
                    WorkoutStore.shared.clearHistory()
                    history = []
                    Theme.hapticNotification(.warning)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all logged sessions from your archive.")
            }
            .onAppear {
                history = WorkoutStore.shared.loadHistory()
            }
        }
    }

    // MARK: - Subviews

    private var summaryStatsCard: some View {
        HStack(spacing: 10) {
            statCol(label: "LOGGED SESSIONS", value: "\(history.count)", color: Theme.emerald)
            statCol(label: "AVG SETS/LIFT", value: history.isEmpty ? "—" : "3.0", color: Theme.sky)
            statCol(label: "CADENCE", value: "0 RIR", color: Theme.amber)
        }
        .padding(14)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func statCol(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Theme.surfaceElevated)
        .cornerRadius(8)
    }

    private var splitFilterPills: some View {
        HStack(spacing: 8) {
            ForEach(["ALL", "PUSH", "PULL", "LEGS"], id: \.self) { split in
                Button(action: {
                    Theme.hapticImpact(.light)
                    selectedSplit = split
                }) {
                    Text(split)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(selectedSplit == split ? .black : Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedSplit == split ? Theme.emerald : Theme.surfaceElevated)
                        .cornerRadius(16)
                }
            }
            Spacer()
        }
    }

    private func historyCard(_ entry: WorkoutHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.exerciseName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 6) {
                        Text(entry.split.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.emerald)
                        Text("•")
                            .foregroundColor(Theme.textMuted)
                        Text(entry.dateString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Target Next")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                    Text(String(format: "%.1f %@", entry.nextTargetWeight, entry.unit.uppercased()))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.emerald)
                }
            }

            Divider().background(Theme.border)

            // Reps Breakdown
            HStack(spacing: 12) {
                repBox(label: "S1", reps: entry.set1Reps, load: entry.loadsUsed.first ?? 0, unit: entry.unit)
                repBox(label: "S2", reps: entry.set2Reps, load: entry.loadsUsed.indices.contains(1) ? entry.loadsUsed[1] : 0, unit: entry.unit)
                if entry.targetSets > 2 {
                    repBox(label: "S3", reps: entry.set3Reps, load: entry.loadsUsed.indices.contains(2) ? entry.loadsUsed[2] : 0, unit: entry.unit)
                }
                Spacer()
            }

            Text(entry.progressionSummary)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
        }
        .padding(14)
        .background(Theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func repBox(label: String, reps: String, load: Double, unit: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Theme.textMuted)
            Text("\(reps)r")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            if load > 0 {
                Text(String(format: "%.1f", load))
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceCard)
        .cornerRadius(6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundColor(Theme.textMuted)
            Text("No Logged Sessions in Filter")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Theme.surfaceElevated)
        .cornerRadius(16)
        .padding(.top, 24)
    }
}
