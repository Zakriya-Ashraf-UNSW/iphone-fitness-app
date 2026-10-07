import Foundation

public struct BackupPayload: Codable {
    public var version: Int = 1
    public var timestamp: Date = Date()
    public var exercises: [Exercise]
    public var history: [WorkoutHistoryEntry]
}

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
        return loadBundledDefaultExercises()
    }

    public func loadBundledDefaultExercises() -> [Exercise] {
        if let bundleURL = Bundle.module.url(forResource: "default_exercises", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let list = try? JSONDecoder().decode([Exercise].self, from: data) {
            saveExercises(list)
            return list
        }
        return []
    }

    public func restoreDefaultExercises() -> [Exercise] {
        let bundled = loadBundledDefaultExercises()
        saveExercises(bundled)
        return bundled
    }

    public func saveExercises(_ exercises: [Exercise]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(exercises) {
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(history) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }

    public func appendHistoryEntry(_ entry: WorkoutHistoryEntry) {
        var hist = loadHistory()
        hist.insert(entry, at: 0)
        saveHistory(hist)
    }

    public func clearHistory() {
        saveHistory([])
    }

    // MARK: - Backup and Restore Payload

    public func exportBackupPayload() -> Data? {
        let exercises = loadExercises()
        let history = loadHistory()
        let payload = BackupPayload(version: 1, timestamp: Date(), exercises: exercises, history: history)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    public func importBackupPayload(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(BackupPayload.self, from: data) {
            if !payload.exercises.isEmpty {
                saveExercises(payload.exercises)
            }
            saveHistory(payload.history)
            return true
        }
        // Fallback: check if raw array of [Exercise]
        if let exercises = try? decoder.decode([Exercise].self, from: data), !exercises.isEmpty {
            saveExercises(exercises)
            return true
        }
        return false
    }
}
