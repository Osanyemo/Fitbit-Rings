import Foundation
import SwiftData
import SwiftUI

@main
struct FitbitRingsApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try Self.makeModelContainer()
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

    private static func makeModelContainer() throws -> ModelContainer {
        let storeURL = try persistentStoreURL()
        let configuration = ModelConfiguration(url: storeURL)

        return try ModelContainer(
            for: CachedDashboardSnapshot.self,
            CachedPreferences.self,
            configurations: configuration
        )
    }

    private static func persistentStoreURL(fileManager: FileManager = .default) throws -> URL {
        let supportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        try fileManager.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )

        return supportDirectory.appendingPathComponent("default.store")
    }
}
