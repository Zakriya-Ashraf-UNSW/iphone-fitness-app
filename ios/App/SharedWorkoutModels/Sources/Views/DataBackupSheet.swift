import SwiftUI
import UniformTypeIdentifiers

public struct BackupFileDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }
    public var data: Data

    public init(data: Data = Data()) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        if let d = configuration.file.regularFileContents {
            self.data = d
        } else {
            self.data = Data()
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

public struct DataBackupSheet: View {
    @ObservedObject var manager: WorkoutSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter: Bool = false
    @State private var showExporter: Bool = false
    @State private var showPasteSheet: Bool = false
    @State private var pastedJSONText: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showConfirmResetDefaults: Bool = false
    @State private var showConfirmClearHistory: Bool = false
    @State private var showConfirmResetCalibration: Bool = false

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    private var exportPayloadData: Data {
        WorkoutStore.shared.exportBackupPayload() ?? Data()
    }

    private var exportString: String {
        WorkoutStore.shared.exportBackupString()
    }

    private var exportFilename: String {
        WorkoutStore.shared.getStandardBackupFilename()
    }

    private var exportFileURL: URL? {
        WorkoutStore.shared.createTemporaryBackupFile()
    }

    private var calibratedCount: Int {
        manager.exercises.filter { $0.isCalibrated }.count
    }

    private var assistedCount: Int {
        manager.exercises.filter { $0.isAssisted }.count
    }

    private var historyCount: Int {
        WorkoutStore.shared.loadHistory().count
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Telemetry Card
                    telemetryCard

                    // File Export & Sharing Section
                    exportSection

                    // File Import & Sync Section
                    importSection

                    // Settings & Audio
                    audioSettingsSection

                    // Granular Reset Actions
                    resetActionsSection
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Sync & Data Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.emerald)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            // Native File Exporter
            .fileExporter(
                isPresented: $showExporter,
                document: BackupFileDocument(data: exportPayloadData),
                contentType: .json,
                defaultFilename: exportFilename
            ) { result in
                switch result {
                case .success(let url):
                    Theme.hapticSuccess()
                    alertMessage = "Backup file successfully saved to:\n\(url.lastPathComponent)"
                    showAlert = true
                case .failure(let error):
                    alertMessage = "Export failed: \(error.localizedDescription)"
                    showAlert = true
                }
            }
            // Native File Importer
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showPasteSheet) {
                pasteRestoreSheet
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog("Restore Factory Defaults?", isPresented: $showConfirmResetDefaults, titleVisibility: .visible) {
                Button("Restore Default Library", role: .destructive) {
                    manager.restoreDefaults()
                    alertMessage = "Default PPL exercises successfully restored."
                    showAlert = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This resets the exercise database to the original bundled routine.")
            }
            .confirmationDialog("Clear All History Logs?", isPresented: $showConfirmClearHistory, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    WorkoutStore.shared.clearHistory()
                    alertMessage = "All past workout history entries have been cleared."
                    showAlert = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .confirmationDialog("Reset All Calibration?", isPresented: $showConfirmResetCalibration, titleVisibility: .visible) {
                Button("Reset All Calibration", role: .destructive) {
                    manager.resetAllCalibration()
                    alertMessage = "All exercises set back to uncalibrated."
                    showAlert = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Resets e1RM, Fatigue Index, and session counts for all exercises.")
            }
        }
    }

    // MARK: - Subviews

    private var telemetryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Database Telemetry", systemImage: "cylinder.split.1x2.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.emerald)
                Spacer()
                Text("LOCAL & APP GROUP")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Theme.sky)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.sky.opacity(0.15))
                    .cornerRadius(4)
            }

            HStack(spacing: 8) {
                dataBox(title: "EXERCISES", value: "\(manager.exercises.count)", color: Theme.textPrimary)
                dataBox(title: "CALIBRATED", value: "\(calibratedCount)", color: Theme.emerald)
                dataBox(title: "ASSISTED", value: "\(assistedCount)", color: Theme.purple)
                dataBox(title: "LOGS", value: "\(historyCount)", color: Theme.sky)
            }

            HStack {
                Text("Complete state: e1RM, FI, loads, counterweight stack limits & history")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("\(max(1, exportPayloadData.count / 1024)) KB")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.amber)
            }
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func dataBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
        .cornerRadius(10)
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Save & Export File", systemImage: "square.and.arrow.up.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("JSON DOCUMENT")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Theme.emerald)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.emerald.opacity(0.15))
                    .cornerRadius(4)
            }

            Text("Saves all exercises, calibrations (e1RM, Fatigue Index, counterweight pin limits), and workout logs into a single syncable file.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)

            VStack(spacing: 10) {
                // 1. Direct Save to Files App / iCloud
                Button(action: {
                    showExporter = true
                    Theme.hapticImpact(.medium)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Save to Files App / iCloud Drive")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.emerald)
                    .cornerRadius(10)
                }

                // 2. ShareLink with real File URL for AirDrop / Mail / Notes / Messages
                if let fileURL = exportFileURL {
                    ShareLink(
                        item: fileURL,
                        preview: SharePreview(exportFilename, image: Image(systemName: "doc.text.fill"))
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "airplayaudio")
                                .font(.system(size: 13, weight: .semibold))
                            Text("AirDrop & Share File via ShareSheet")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }
                }

                HStack(spacing: 10) {
                    // 3. Save to app Documents folder
                    Button(action: {
                        if let savedURL = WorkoutStore.shared.saveBackupToDocumentsDirectory() {
                            Theme.hapticSuccess()
                            alertMessage = "File saved directly into app's Documents folder:\n\(savedURL.lastPathComponent)\n\nAccessible via the iOS Files app under 'On My iPhone' -> 'Overload'."
                            showAlert = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "internaldrive.fill")
                            Text("Save Locally")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(8)
                    }

                    // 4. Copy JSON string to clipboard
                    Button(action: {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = exportString
                        Theme.hapticSuccess()
                        alertMessage = "JSON dataset copied to clipboard for quick paste transfer."
                        showAlert = true
                        #endif
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc.fill")
                            Text("Copy JSON")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Restore & Sync Data", systemImage: "square.and.arrow.down.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Import a previously exported backup file or sync from another device. Replaces routine calibrations and appends session logs.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 10) {
                Button(action: {
                    showImporter = true
                    Theme.hapticImpact(.medium)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                        Text("Select JSON File")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }

                Button(action: {
                    #if canImport(UIKit)
                    if let clip = UIPasteboard.general.string, !clip.isEmpty {
                        pastedJSONText = clip
                    }
                    #endif
                    showPasteSheet = true
                    Theme.hapticImpact(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.badge.plus")
                        Text("Paste JSON")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.emerald)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.emerald.opacity(0.4), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var audioSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audio & Sensory Cues", systemImage: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Toggle(isOn: Binding(
                get: { !manager.isMuted },
                set: { _ in manager.toggleMute() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sound Alerts")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Plays completion chime when rest interval ends")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .tint(Theme.emerald)
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var resetActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Granular Reset Controls", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.amber)

            VStack(spacing: 8) {
                Button(action: { showConfirmResetCalibration = true }) {
                    resetRow(title: "Reset All Calibration States", subtitle: "Clear e1RM & FI for all lifts", isDestructive: false)
                }

                Button(action: { showConfirmClearHistory = true }) {
                    resetRow(title: "Clear Workout History Archive", subtitle: "Permanently purge session logs", isDestructive: true)
                }

                Button(action: { showConfirmResetDefaults = true }) {
                    resetRow(title: "Restore Factory Default Exercises", subtitle: "Reset routine to bundled PPL dataset", isDestructive: true)
                }
            }
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func resetRow(title: String, subtitle: String, isDestructive: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDestructive ? Theme.crimson : Theme.amber)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textMuted)
        }
        .padding(12)
        .background(Theme.surfaceElevated)
        .cornerRadius(8)
    }

    private var pasteRestoreSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste the full JSON payload exported from another device or web app to sync all calibrations and history.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal)

                TextEditor(text: $pastedJSONText)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    .padding(.horizontal)

                Button(action: {
                    if let data = pastedJSONText.data(using: .utf8) {
                        let result = WorkoutStore.shared.importBackupPayload(data)
                        if result.success {
                            manager.reloadData()
                            Theme.hapticSuccess()
                            showPasteSheet = false
                            alertMessage = result.message
                            showAlert = true
                        } else {
                            alertMessage = result.message
                            showAlert = true
                        }
                    }
                }) {
                    Text("Parse & Restore Data")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(pastedJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textMuted : Theme.emerald)
                        .cornerRadius(10)
                }
                .disabled(pastedJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Paste JSON Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPasteSheet = false }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            guard selectedURL.startAccessingSecurityScopedResource() else {
                alertMessage = "Failed to access the selected file."
                showAlert = true
                return
            }
            defer { selectedURL.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: selectedURL) {
                let importResult = WorkoutStore.shared.importBackupPayload(data)
                if importResult.success {
                    manager.reloadData()
                    Theme.hapticSuccess()
                    alertMessage = importResult.message
                    showAlert = true
                } else {
                    alertMessage = importResult.message
                    showAlert = true
                }
            } else {
                alertMessage = "Failed to read the file contents."
                showAlert = true
            }
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
