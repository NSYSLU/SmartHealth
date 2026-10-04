import SwiftUI

@main
struct SmartHealthApp: App {
    @State private var store = HealthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
