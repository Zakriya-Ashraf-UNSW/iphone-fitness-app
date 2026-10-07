import SwiftUI
import UniformTypeIdentifiers

public struct BackupFileDocument: Transferable {
    public var data: Data

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { doc in
            doc.data
        }
    }
}

public struct DataBackupSheet: View {
    @ObservedObject var manager: WorkoutSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter: Bool = false
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
        String(data: exportPayloadData, encoding: .utf8) ?? "{}"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Telemetry Card
                    telemetryCard

                    // Native Export & Share
                    exportSection

                    // Import Section
                    importSection

                    // Settings & Audio
                    audioSettingsSection

                    // Granular Reset Actions
                    resetActionsSection
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Data & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.emerald)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
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
                Text("LOCAL APP GROUP")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Theme.sky)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.sky.opacity(0.15))
                    .cornerRadius(4)
            }

            HStack(spacing: 12) {
                dataBox(title: "EXERCISES", value: "\(manager.exercises.count)", color: Theme.textPrimary)
                dataBox(title: "HISTORY LOGS", value: "\(WorkoutStore.shared.loadHistory().count)", color: Theme.sky)
                dataBox(title: "PAYLOAD SIZE", value: "\(exportPayloadData.count / 1024) KB", color: Theme.amber)
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
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
        .cornerRadius(10)
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export & Cloud Sharing", systemImage: "square.and.arrow.up.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Export complete workout database as JSON via AirDrop, iCloud Drive, Files, or Notes.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 10) {
                ShareLink(
                    item: exportString,
                    preview: SharePreview("Overload_DPO_Backup.json", image: Image(systemName: "dumbbell.fill"))
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export JSON via Share Sheet")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.emerald)
                    .cornerRadius(10)
                }

                Button(action: {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = exportString
                    Theme.hapticSuccess()
                    alertMessage = "JSON dataset copied to clipboard."
                    showAlert = true
                    #endif
                }) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Theme.surfaceElevated)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Theme.surfaceCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Import Database", systemImage: "square.and.arrow.down.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Restore exercises and workout history from an exported Overload JSON file.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)

            Button(action: {
                showImporter = true
            }) {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Select JSON File from Files App")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.surfaceElevated)
                .cornerRadius(10)
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

            if let data = try? Data(contentsOf: selectedURL),
               WorkoutStore.shared.importBackupPayload(data) {
                manager.reloadData()
                Theme.hapticSuccess()
                alertMessage = "Database successfully restored from JSON file."
                showAlert = true
            } else {
                alertMessage = "Invalid backup format or corrupt JSON file."
                showAlert = true
            }
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
