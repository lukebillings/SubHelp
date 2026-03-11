import SwiftUI

@main
struct SubHelpApp: App {
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Subscriptions", systemImage: "diamond.fill") {
                    HomeView(viewModel: homeViewModel)
                }
                Tab("Settings", systemImage: "gearshape.fill") {
                    SettingsView()
                }
            }
            .tint(.blue)
        }
    }
}
