import SwiftUI

public struct MainTabView: View {
    @StateObject private var manager = WorkoutSessionManager.shared
    @State private var selectedTab: Int = 0

    public init() {
        // Tab bar appearance tailored for iPhone 16 Pro Max OLED display
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 9/255, green: 9/255, blue: 11/255, alpha: 0.95)
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    public var body: some View {
        TabView(selection: $manager.selectedTab) {
            // Tab 0: Focused Workout Chamber
            WorkoutChamberView(manager: manager)
                .tabItem {
                    Label("Chamber", systemImage: "bolt.fill")
                }
                .tag(0)

            // Tab 1: PPL Lifts Hub
            ExerciseHubView(manager: manager, selectedTab: $manager.selectedTab)
                .tabItem {
                    Label("Lifts", systemImage: "dumbbell.fill")
                }
                .tag(1)

            // Tab 2: Calibration Hub
            CalibrationHubView(manager: manager)
                .tabItem {
                    Label("Calibration", systemImage: "gauge.with.needle.fill")
                }
                .tag(2)

            // Tab 3: Swift Charts Overload Projections
            OverloadProjectionsView(manager: manager)
                .tabItem {
                    Label("Projections", systemImage: "chart.xyaxis.line")
                }
                .tag(3)

            // Tab 4: DPO Handbook & Workout History Logs
            HandbookAndLogsView(manager: manager)
                .tabItem {
                    Label("Handbook", systemImage: "book.closed.fill")
                }
                .tag(4)
        }
        .accentColor(Theme.emerald)
    }
}
