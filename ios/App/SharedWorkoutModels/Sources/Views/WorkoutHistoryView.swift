import SwiftUI

public enum HistoryTypeFilter: String, CaseIterable, Identifiable {
    case all = "ALL"
    case workouts = "WORKOUTS"
    case calibrations = "CALIBRATIONS"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .workouts: return "bolt.fill"
        case .calibrations: return "gauge.with.needle.fill"
        }
    }
}

public struct WorkoutHistoryView: View {
    @State private var history: [WorkoutHistoryEntry] = []
    @State private var selectedType: HistoryTypeFilter = .all
    @State private var selectedSplit: String = "ALL"
    @State private var searchText: String = ""
    @State private var showClearConfirm: Bool = false
    @State private var entryToDelete: WorkoutHistoryEntry? = nil
    @State private var showDeleteEntryConfirm: Bool = false

    public init() {}

    private var workoutsCount: Int {
        history.filter { !$0.isCalibrationEntry }.count
    }

    private var calibrationsCount: Int {
        history.filter { $0.isCalibrationEntry }.count
    }

    private var filteredHistory: [WorkoutHistoryEntry] {
        history.filter { entry in
            // Type filter
            switch selectedType {
            case .all:
                break
            case .workouts:
                if entry.isCalibrationEntry { return false }
            case .calibrations:
                if !entry.isCalibrationEntry { return false }
            }

            // Split filter
            if selectedSplit != "ALL" && entry.split.uppercased() != selectedSplit.uppercased() {
                return false
            }

            // Search filter
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !q.isEmpty {
                let matchName = entry.exerciseName.lowercased().contains(q)
                let matchSplit = entry.split.lowercased().contains(q)
                if !matchName && !matchSplit { return false }
            }

            return true
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary Stats Card
                    summaryStatsCard

                    // Search & Clear Bar
                    searchBar

                    // Type Filter Tabs (All / Workouts / Calibrations)
                    typeFilterSegment

                    // Split Filter Pills
                    splitFilterPills

                    // Filter Status & Count
                    filterStatusHeader

                    // History Entries
                    if filteredHistory.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredHistory) { entry in
                                if entry.isCalibrationEntry {
                                    calibrationCard(entry)
                                } else {
                                    workoutCard(entry)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("History Archive")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !history.isEmpty {
                        Button(action: { showClearConfirm = true }) {
                            Text("Clear All")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.crimson)
                        }
                    }
                }
            }
            .confirmationDialog("Clear All History?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear Entire Archive", role: .destructive) {
                    WorkoutStore.shared.clearHistory()
                    history = []
                    Theme.hapticNotification(.warning)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all logged workouts and calibrations from your archive.")
            }
            .confirmationDialog("Delete Entry?", isPresented: $showDeleteEntryConfirm, titleVisibility: .visible) {
                if let entry = entryToDelete {
                    Button("Delete \(entry.exerciseName) Entry", role: .destructive) {
                        deleteEntry(entry)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this recorded entry?")
            }
            .onAppear {
                reloadHistory()
            }
        }
    }

    private func reloadHistory() {
        history = WorkoutStore.shared.loadHistory()
    }

    private func deleteEntry(_ entry: WorkoutHistoryEntry) {
        WorkoutStore.shared.deleteHistoryEntry(id: entry.id)
        history.removeAll { $0.id == entry.id }
        Theme.hapticNotification(.warning)
    }

    // MARK: - Subviews

    private var summaryStatsCard: some View {
        HStack(spacing: 8) {
            statCol(label: "TOTAL ARCHIVE", value: "\(history.count)", color: Theme.textPrimary)
            statCol(label: "WORKOUTS", value: "\(workoutsCount)", color: Theme.emerald)
            statCol(label: "CALIBRATIONS", value: "\(calibrationsCount)", color: Theme.cyan)
        }
        .padding(12)
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
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
        .cornerRadius(8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)

            TextField("Filter by exercise name...", text: $searchText)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    Theme.hapticImpact(.light)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.surfaceElevated)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    private var typeFilterSegment: some View {
        HStack(spacing: 8) {
            ForEach(HistoryTypeFilter.allCases) { filter in
                let isSelected = selectedType == filter
                let count: Int = {
                    switch filter {
                    case .all: return history.count
                    case .workouts: return workoutsCount
                    case .calibrations: return calibrationsCount
                    }
                }()

                Button(action: {
                    Theme.hapticImpact(.light)
                    selectedType = filter
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 10, weight: .bold))

                        Text(filter.rawValue)
                            .font(.system(size: 11, weight: .bold))

                        Text("(\(count))")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(isSelected ? .black : Theme.textSecondary)
                    .background(
                        isSelected ?
                            (filter == .calibrations ? Theme.cyan : (filter == .workouts ? Theme.emerald : Color.white))
                            : Theme.surfaceElevated
                    )
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.clear : Theme.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var splitFilterPills: some View {
        HStack(spacing: 8) {
            ForEach(["ALL", "PUSH", "PULL", "LEGS"], id: \.self) { split in
                let isSelected = selectedSplit == split
                Button(action: {
                    Theme.hapticImpact(.light)
                    selectedSplit = split
                }) {
                    Text(split)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSelected ? .black : Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isSelected ? Theme.emerald : Theme.surfaceElevated)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.clear : Theme.border, lineWidth: 1)
                        )
                }
            }
            Spacer()
        }
    }

    private var filterStatusHeader: some View {
        HStack {
            Text("SHOWING \(filteredHistory.count) OF \(history.count) RECORDS")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textMuted)

            Spacer()

            if selectedType != .all || selectedSplit != "ALL" || !searchText.isEmpty {
                Button(action: {
                    Theme.hapticImpact(.light)
                    selectedType = .all
                    selectedSplit = "ALL"
                    searchText = ""
                }) {
                    Text("Reset Filters")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.cyan)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Workout Card

    private func workoutCard(_ entry: WorkoutHistoryEntry) -> some View {
        let isAssisted = entry.isAssisted ?? false
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.exerciseName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)

                        Text("WORKOUT")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.emerald)
                            .cornerRadius(4)

                        if isAssisted {
                            Text("ASSIST")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.purple)
                                .cornerRadius(4)
                        }
                    }

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
                    Text(isAssisted ? "Next Assist Pin" : "Target Next")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                    Text(String(format: "%.1f %@", entry.nextTargetWeight, entry.unit.uppercased()))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(isAssisted ? Theme.purple : Theme.emerald)
                }
            }

            Divider().background(Theme.border)

            // Reps Breakdown
            HStack(spacing: 10) {
                repBox(label: "S1", reps: entry.set1Reps, load: entry.loadsUsed.first ?? 0, unit: entry.unit, isAssisted: isAssisted)
                repBox(label: "S2", reps: entry.set2Reps, load: entry.loadsUsed.indices.contains(1) ? entry.loadsUsed[1] : 0, unit: entry.unit, isAssisted: isAssisted)
                if entry.targetSets > 2 {
                    repBox(label: "S3", reps: entry.set3Reps, load: entry.loadsUsed.indices.contains(2) ? entry.loadsUsed[2] : 0, unit: entry.unit, isAssisted: isAssisted)
                }
                Spacer()

                Button(action: {
                    entryToDelete = entry
                    showDeleteEntryConfirm = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                        .padding(6)
                }
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

    // MARK: - Calibration Card

    private func calibrationCard(_ entry: WorkoutHistoryEntry) -> some View {
        let isAssisted = entry.isAssisted ?? false
        let fiPct = Int(round(entry.fatigueIndex * 100))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.exerciseName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)

                        HStack(spacing: 3) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.system(size: 7))
                            Text("CALIBRATION")
                                .font(.system(size: 8, weight: .black))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.cyan)
                        .cornerRadius(4)

                        if isAssisted {
                            Text("ASSIST")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.purple)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(entry.split.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.cyan)
                        Text("•")
                            .foregroundColor(Theme.textMuted)
                        Text(entry.dateString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("e1RM")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                        Text(String(format: "%.1f %@", entry.e1RM, entry.unit.uppercased()))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.cyan)
                    }

                    HStack(spacing: 4) {
                        Text("Fatigue")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                        Text("\(fiPct)%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(Theme.amber)
                    }
                }
            }

            Divider().background(Theme.cyan.opacity(0.3))

            // Calibration Benchmark Sets Grid
            HStack(spacing: 8) {
                // Set 1 Anchor
                calibrationSetBox(
                    title: "SET 1 (ANCHOR)",
                    reps: entry.set1Reps,
                    load: entry.loadsUsed.first ?? 0,
                    unit: entry.unit,
                    accent: Theme.cyan,
                    isAssisted: isAssisted
                )

                // Set 2 Drop
                calibrationSetBox(
                    title: isAssisted ? "SET 2 (+20% AST)" : "SET 2 (-20% DROP)",
                    reps: entry.set2Reps,
                    load: entry.loadsUsed.indices.contains(1) ? entry.loadsUsed[1] : 0,
                    unit: entry.unit,
                    accent: Theme.sky,
                    isAssisted: isAssisted
                )

                // Calibrated Target Cascade
                VStack(alignment: .leading, spacing: 2) {
                    Text("PRESCRIBED")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.textMuted)

                    if entry.nextLoads.count >= 3 {
                        Text("W1: \(String(format: "%.1f", entry.nextLoads[0]))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.emerald)
                        Text("W2: \(String(format: "%.1f", entry.nextLoads[1]))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.sky)
                        Text("W3: \(String(format: "%.1f", entry.nextLoads[2]))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.amber)
                    } else {
                        Text(String(format: "%.1f %@", entry.nextTargetWeight, entry.unit.uppercased()))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.emerald)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.surfaceCard)
                .cornerRadius(6)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    entryToDelete = entry
                    showDeleteEntryConfirm = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                        .padding(6)
                }
            }

            Text(entry.progressionSummary)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
        }
        .padding(14)
        .background(Theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.cyan.opacity(0.4), lineWidth: 1)
        )
    }

    private func calibrationSetBox(
        title: String,
        reps: String,
        load: Double,
        unit: String,
        accent: Color,
        isAssisted: Bool
    ) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 7, weight: .black))
                .foregroundColor(accent)
                .lineLimit(1)

            Text("\(reps)r")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            HStack(spacing: 2) {
                Text(String(format: "%.1f", load))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Text(unit)
                    .font(.system(size: 7))
                    .foregroundColor(Theme.textMuted)
                if isAssisted {
                    Text("ast")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.purple)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Theme.surfaceCard)
        .cornerRadius(6)
    }

    private func repBox(label: String, reps: String, load: Double, unit: String, isAssisted: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Theme.textMuted)
            Text("\(reps)r")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            if load > 0 {
                HStack(spacing: 2) {
                    Text(String(format: "%.1f", load))
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary)
                    if isAssisted {
                        Text("ast")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Theme.purple)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceCard)
        .cornerRadius(6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedType == .calibrations ? "gauge.with.needle" : "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundColor(Theme.textMuted)

            Text(selectedType == .calibrations ? "No Calibrations in Filter" : "No Logged Entries in Filter")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textSecondary)

            if selectedType != .all || selectedSplit != "ALL" || !searchText.isEmpty {
                Button(action: {
                    selectedType = .all
                    selectedSplit = "ALL"
                    searchText = ""
                }) {
                    Text("Clear Filter Criteria")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.emerald)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceCard)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Theme.surfaceElevated)
        .cornerRadius(16)
        .padding(.top, 24)
    }
}
