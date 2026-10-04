import Foundation

public final class WorkoutStore: @unchecked Sendable {
    public static let shared = WorkoutStore()

    private let appGroupID = "group.com.overload.fitnessapp"
    private let exercisesFilename = "exercises_v1.json"
    private let historyFilename = "workout_history_v1.json"

    private var storageDirectory: URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return groupURL
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var exercisesFileURL: URL {
        storageDirectory.appendingPathComponent(exercisesFilename)
    }

    private var historyFileURL: URL {
        storageDirectory.appendingPathComponent(historyFilename)
    }

    private init() {}

    public func loadExercises() -> [Exercise] {
        if FileManager.default.fileExists(atPath: exercisesFileURL.path),
           let data = try? Data(contentsOf: exercisesFileURL),
           let list = try? JSONDecoder().decode([Exercise].self, from: data),
           !list.isEmpty {
            return list
        }
        // Fallback to bundled default_exercises.json
        if let bundleURL = Bundle.module.url(forResource: "default_exercises", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let list = try? JSONDecoder().decode([Exercise].self, from: data) {
            saveExercises(list)
            return list
        }
        return []
    }

    public func saveExercises(_ exercises: [Exercise]) {
        if let data = try? JSONEncoder().encode(exercises) {
            try? data.write(to: exercisesFileURL, options: .atomic)
        }
    }

    public func loadHistory() -> [WorkoutHistoryEntry] {
        if FileManager.default.fileExists(atPath: historyFileURL.path),
           let data = try? Data(contentsOf: historyFileURL),
           let list = try? JSONDecoder().decode([WorkoutHistoryEntry].self, from: data) {
            return list
        }
        return []
    }

    public func saveHistory(_ history: [WorkoutHistoryEntry]) {
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }

    public func appendHistoryEntry(_ entry: WorkoutHistoryEntry) {
        var hist = loadHistory()
        hist.insert(entry, at: 0)
        saveHistory(hist)
    }
}
