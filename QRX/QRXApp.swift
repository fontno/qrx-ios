import SwiftData
import SwiftUI

@main
struct QRXApp: App {
    private let containerResult: Result<ModelContainer, Error>

    init() {
        do {
            // UI tests opt into an isolated throwaway store; real launches
            // deliberately have no in-memory fallback — silently opening a
            // throwaway store would look like data loss to the user.
            let inMemory = CommandLine.arguments.contains("--uitest-inmemory")
            containerResult = .success(try SharedStore.makeContainer(
                inMemory: inMemory,
                migrateLegacyStore: true,
                syncEnabled: !inMemory
            ))
        } catch {
            containerResult = .failure(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case .success(let container):
                LibraryView()
                    .modelContainer(container)
                    // Monochrome chrome: controls tint black/white, not blue.
                    .tint(.primary)
            case .failure(let error):
                ContentUnavailableView {
                    Label("Can't Open Your Library", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Your saved codes couldn't be loaded. Please restart the app; if this keeps happening, contact support.\n\n\(error.localizedDescription)")
                }
            }
        }
    }
}
