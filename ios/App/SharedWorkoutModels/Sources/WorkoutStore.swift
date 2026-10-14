import Foundation

public struct BackupStats: Codable, Hashable {
    public var totalExercises: Int
    public var calibratedCount: Int
    public var counterweightCount: Int
    public var historyLogsCount: Int
    public var exportedAt: String

    public init(totalExercises: Int, calibratedCount: Int, counterweightCount: Int, historyLogsCount: Int, exportedAt: String) {
        self.totalExercises = totalExercises
        self.calibratedCount = calibratedCount
        self.counterweightCount = counterweightCount
        self.historyLogsCount = historyLogsCount
        self.exportedAt = exportedAt
    }
}

public struct BackupSettings: Codable, Hashable {
    public var defaultUnit: String
    public var isMuted: Bool
    public var pacingMode: String

    public init(defaultUnit: String = "lbs", isMuted: Bool = false, pacingMode: String = "FAST_PACED") {
        self.defaultUnit = defaultUnit
        self.isMuted = isMuted
        self.pacingMode = pacingMode
    }
}

public struct BackupPayload: Codable {
    public var version: Int = 1
    public var app: String = "Overload DPO Hypertrophy Engine"
    public var exportedAt: String
    public var timestamp: Date
    public var stats: BackupStats
    public var exercises: [Exercise]
    public var history: [WorkoutHistoryEntry]
    public var settings: BackupSettings?

    enum CodingKeys: String, CodingKey {
        case version, app, exportedAt, timestamp, stats, exercises, history
        case workoutHistory, workout_history, settings
    }

    public init(
        version: Int = 1,
        app: String = "Overload DPO Hypertrophy Engine",
        exportedAt: String = ISO8601DateFormatter().string(from: Date()),
        timestamp: Date = Date(),
        stats: BackupStats,
        exercises: [Exercise],
        history: [WorkoutHistoryEntry],
        settings: BackupSettings? = nil
    ) {
        self.version = version
        self.app = app
        self.exportedAt = exportedAt
        self.timestamp = timestamp
        self.stats = stats
        self.exercises = exercises
        self.history = history
        self.settings = settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        app = try container.decodeIfPresent(String.self, forKey: .app) ?? "Overload DPO Hypertrophy Engine"
        exportedAt = try container.decodeIfPresent(String.self, forKey: .exportedAt) ?? ISO8601DateFormatter().string(from: Date())
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()

        exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []

        if let h = try? container.decode([WorkoutHistoryEntry].self, forKey: .history) {
            history = h
        } else if let h = try? container.decode([WorkoutHistoryEntry].self, forKey: .workoutHistory) {
            history = h
        } else if let h = try? container.decode([WorkoutHistoryEntry].self, forKey: .workout_history) {
            history = h
        } else {
            history = []
        }

        settings = try container.decodeIfPresent(BackupSettings.self, forKey: .settings)

        if let s = try? container.decode(BackupStats.self, forKey: .stats) {
            stats = s
        } else {
            stats = BackupStats(
                totalExercises: exercises.count,
                calibratedCount: exercises.filter { $0.isCalibrated }.count,
                counterweightCount: exercises.filter { $0.isAssisted }.count,
                historyLogsCount: history.count,
                exportedAt: exportedAt
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(app, forKey: .app)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(stats, forKey: .stats)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(history, forKey: .history)
        try container.encodeIfPresent(settings, forKey: .settings)
    }
}

public struct ImportResult: Hashable {
    public var success: Bool
    public var exercisesImported: Int
    public var calibratedImported: Int
    public var counterweightImported: Int
    public var historyLogsImported: Int
    public var message: String

    public init(
        success: Bool,
        exercisesImported: Int = 0,
        calibratedImported: Int = 0,
        counterweightImported: Int = 0,
        historyLogsImported: Int = 0,
        message: String
    ) {
        self.success = success
        self.exercisesImported = exercisesImported
        self.calibratedImported = calibratedImported
        self.counterweightImported = counterweightImported
        self.historyLogsImported = historyLogsImported
        self.message = message
    }
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

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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

    public func deleteHistoryEntry(id: String) {
        var hist = loadHistory()
        hist.removeAll { $0.id == id }
        saveHistory(hist)
    }

    public func clearHistory() {
        saveHistory([])
    }

    // MARK: - Backup and Restore Payload

    public func createBackupPayload() -> BackupPayload {
        let exercises = loadExercises()
        let history = loadHistory()
        let dateString = ISO8601DateFormatter().string(from: Date())
        let stats = BackupStats(
            totalExercises: exercises.count,
            calibratedCount: exercises.filter { $0.isCalibrated }.count,
            counterweightCount: exercises.filter { $0.isAssisted }.count,
            historyLogsCount: history.count,
            exportedAt: dateString
        )
        return BackupPayload(
            version: 1,
            app: "Overload DPO Hypertrophy Engine",
            exportedAt: dateString,
            timestamp: Date(),
            stats: stats,
            exercises: exercises,
            history: history,
            settings: BackupSettings()
        )
    }

    public func exportBackupPayload() -> Data? {
        let payload = createBackupPayload()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    public func exportBackupString() -> String {
        guard let data = exportBackupPayload(),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    public func getStandardBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = formatter.string(from: Date())
        return "Overload_DPO_Backup_\(timestamp).json"
    }

    /// Creates an actual JSON file on disk in the temporary directory suitable for ShareLink and AirDrop
    public func createTemporaryBackupFile() -> URL? {
        guard let data = exportBackupPayload() else { return nil }
        let filename = getStandardBackupFilename()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }

    /// Saves the backup JSON directly to the app's persistent Documents directory (accessible via iOS Files app)
    public func saveBackupToDocumentsDirectory() -> URL? {
        guard let data = exportBackupPayload() else { return nil }
        let filename = getStandardBackupFilename()
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Imports backup JSON data from iOS app, web export, or raw JSON formats
    public func importBackupPayload(_ data: Data) -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Strategy 1: Standard or Web BackupPayload
        if let payload = try? decoder.decode(BackupPayload.self, from: data) {
            let exCount = payload.exercises.count
            let calCount = payload.exercises.filter { $0.isCalibrated }.count
            let assistedCount = payload.exercises.filter { $0.isAssisted }.count
            let histCount = payload.history.count

            if !payload.exercises.isEmpty {
                saveExercises(payload.exercises)
            }
            saveHistory(payload.history)

            return ImportResult(
                success: true,
                exercisesImported: exCount,
                calibratedImported: calCount,
                counterweightImported: assistedCount,
                historyLogsImported: histCount,
                message: "Successfully restored \(exCount) lifts (\(calCount) calibrated, \(assistedCount) counterweight) and \(histCount) history logs."
            )
        }

        // Strategy 2: Raw array of [Exercise]
        if let exercises = try? decoder.decode([Exercise].self, from: data), !exercises.isEmpty {
            let calCount = exercises.filter { $0.isCalibrated }.count
            let assistedCount = exercises.filter { $0.isAssisted }.count
            saveExercises(exercises)
            return ImportResult(
                success: true,
                exercisesImported: exercises.count,
                calibratedImported: calCount,
                counterweightImported: assistedCount,
                historyLogsImported: 0,
                message: "Successfully imported \(exercises.count) exercises (\(calCount) calibrated, \(assistedCount) counterweight)."
            )
        }

        // Strategy 3: Raw array of [WorkoutHistoryEntry]
        if let history = try? decoder.decode([WorkoutHistoryEntry].self, from: data), !history.isEmpty {
            saveHistory(history)
            return ImportResult(
                success: true,
                exercisesImported: 0,
                calibratedImported: 0,
                counterweightImported: 0,
                historyLogsImported: history.count,
                message: "Successfully restored \(history.count) workout history session logs."
            )
        }

        return ImportResult(
            success: false,
            message: "Invalid or unrecognized backup format. Please verify the JSON structure."
        )
    }
}
