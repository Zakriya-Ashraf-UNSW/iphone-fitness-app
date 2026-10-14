import SwiftUI

public struct ExerciseHubView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @Binding var selectedTab: Int

    @State private var searchQuery: String = ""
    @State private var selectedCategory: ExerciseCategory? = nil
    @State private var showAddExerciseSheet: Bool = false
    @State private var exerciseToEdit: Exercise? = nil

    public init(manager: WorkoutSessionManager, selectedTab: Binding<Int>) {
        self.manager = manager
        self._selectedTab = selectedTab
    }

    private var filteredExercises: [Exercise] {
        manager.exercisesForCurrentSplit.filter { ex in
            if let cat = selectedCategory, ex.category != cat { return false }
            if !searchQuery.isEmpty && !ex.name.localizedCaseInsensitiveContains(searchQuery) && !ex.muscleGroup.localizedCaseInsensitiveContains(searchQuery) {
                return false
            }
            return true
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Split Selector
                    splitSelector

                    // Search & Category Filters
                    searchAndFilters

                    // Start Routine Banner
                    routineBanner

                    // Exercise List
                    if filteredExercises.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredExercises) { exercise in
                                exerciseRow(exercise)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Lifts Hub")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Theme.hapticImpact(.light)
                        showAddExerciseSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Lift")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.emerald)
                    }
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddEditExerciseSheet(manager: manager)
            }
            .sheet(item: $exerciseToEdit) { ex in
                AddEditExerciseSheet(manager: manager, exerciseToEdit: ex)
            }
        }
    }

    // MARK: - Subviews

    private var splitSelector: some View {
        HStack(spacing: 8) {
            ForEach(WorkoutSplit.allCases) { split in
                Button(action: {
                    Theme.hapticImpact(.light)
                    manager.currentSplit = split
                    manager.activeExerciseIndex = 0
                }) {
                    Text(split.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(manager.currentSplit == split ? .black : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(manager.currentSplit == split ? Theme.emerald : Theme.surfaceElevated)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(manager.currentSplit == split ? Theme.emerald : Theme.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textMuted)
                TextField("Search lifts by name or muscle...", text: $searchQuery)
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

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryPill(title: "ALL", category: nil)
                    ForEach(ExerciseCategory.allCases) { cat in
                        categoryPill(title: cat.displayName, category: cat)
                    }
                }
            }
        }
    }

    private func categoryPill(title: String, category: ExerciseCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button(action: {
            Theme.hapticImpact(.light)
            selectedCategory = category
        }) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? .black : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.emerald : Theme.surfaceElevated)
                .cornerRadius(16)
        }
    }

    private var routineBanner: some View {
        Button(action: {
            manager.startRoutine(split: manager.currentSplit)
            selectedTab = 0
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("START \(manager.currentSplit.rawValue) WORKOUT")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                    Text("\(manager.exercisesForCurrentSplit.count) Lifts • Progressive Overload Engine Active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.8))
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.black)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Theme.emerald, Theme.emerald.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(14)
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)

                        if exercise.isAssisted {
                            Text("ASSIST")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.purple)
                                .cornerRadius(4)
                        }

                        Button(action: {
                            exerciseToEdit = exercise
                        }) {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textMuted)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(exercise.muscleGroup)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.emerald)
                        Text("•")
                            .foregroundColor(Theme.textMuted)
                        Text(exercise.equipmentType.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        Text("•")
                            .foregroundColor(Theme.textMuted)
                        Text("\(exercise.repWindowMin)–\(exercise.repWindowMax)r")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.sky)
                    }
                }

                Spacer()

                Button(action: {
                    manager.startLift(exerciseId: exercise.id)
                    selectedTab = 0
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                        Text("Train")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.emerald.opacity(0.18))
                    .foregroundColor(Theme.emerald)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.emerald.opacity(0.4), lineWidth: 1)
                    )
                }
            }

            // Loads Row
            HStack(spacing: 8) {
                loadBadge(label: "SET 1", load: exercise.loads.first ?? exercise.weight, unit: exercise.unit, isAssisted: exercise.isAssisted, highlight: Theme.emerald)
                if exercise.loads.count > 1 {
                    loadBadge(label: "SET 2", load: exercise.loads[1], unit: exercise.unit, isAssisted: exercise.isAssisted, highlight: Theme.cyan)
                }
                if exercise.loads.count > 2 && exercise.activeSetsCount > 2 {
                    loadBadge(label: "SET 3", load: exercise.loads[2], unit: exercise.unit, isAssisted: exercise.isAssisted, highlight: Theme.amber)
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(exercise.isAssisted ? "ASSIST FLOOR" : "e1RM")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                    if exercise.isAssisted {
                        Text(String(format: "%.0f %@", exercise.effectiveMinWeight, exercise.unit))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.purple)
                    } else {
                        Text(exercise.e1RM > 0 ? String(format: "%.1f %@", exercise.e1RM, exercise.unit) : "—")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.surfaceElevated)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func loadBadge(label: String, load: Double, unit: String, isAssisted: Bool = false, highlight: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(highlight)
            HStack(spacing: 2) {
                Text(String(format: "%.1f", load))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                if isAssisted {
                    Text("ast")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.purple)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceCard)
        .cornerRadius(6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell")
                .font(.system(size: 32))
                .foregroundColor(Theme.textMuted)
            Text("No lifts found for this filter.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
