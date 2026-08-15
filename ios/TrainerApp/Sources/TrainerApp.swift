import SwiftData
import SwiftUI
import TrainerPersistence

@main
struct TrainerApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try TrainerPersistenceContainer.makeDefault()
        } catch {
            fatalError("Local workout storage could not be initialized.")
        }
    }

    var body: some Scene {
        WindowGroup {
            TrainerRootView()
        }
        .modelContainer(modelContainer)
    }
}
