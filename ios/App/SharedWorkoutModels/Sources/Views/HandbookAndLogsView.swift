import SwiftUI

public struct HandbookAndLogsView: View {
    @ObservedObject var manager: WorkoutSessionManager
    @State private var selectedSegment: Int = 0 // 0: Handbook, 1: History
    @State private var showSettingsSheet: Bool = false

    public init(manager: WorkoutSessionManager) {
        self.manager = manager
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Section", selection: $selectedSegment) {
                    Text("DPO Handbook").tag(0)
                    Text("History Archive").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.surface)

                // Selected Content
                if selectedSegment == 0 {
                    DPOHandbookView()
                } else {
                    WorkoutHistoryView()
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Theme.hapticImpact(.light)
                        showSettingsSheet = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                DataBackupSheet(manager: manager)
            }
        }
    }
}
