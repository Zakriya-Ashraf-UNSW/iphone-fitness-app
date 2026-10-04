import SwiftUI

public struct MainTabView: View {
    @StateObject private var manager = WorkoutSessionManager.shared
    @State private var selectedTab: Int = 0

    public init() {
        // Tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 9/255, green: 9/255, blue: 11/255, alpha: 1.0)
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutChamberView(manager: manager)
                .tabItem {
                    Label("Chamber", systemImage: "bolt.fill")
                }
                .tag(0)

            ExerciseHubView(manager: manager, selectedTab: $selectedTab)
                .tabItem {
                    Label("Lifts Hub", systemImage: "dumbbell.fill")
                }
                .tag(1)

            WorkoutHistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)
        }
        .accentColor(Theme.emerald)
    }
}
