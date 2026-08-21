import SwiftData
import SwiftUI

@main
struct FitbitRingsApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: CachedDashboardSnapshot.self,
                CachedPreferences.self
            )
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
