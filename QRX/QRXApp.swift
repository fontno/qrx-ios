import SwiftData
import SwiftUI

@main
struct QRXApp: App {
    private let containerResult: Result<ModelContainer, Error>

    init() {
        // UI tests opt into an isolated throwaway store; real launches
        // deliberately have no in-memory fallback — silently opening a
        // throwaway store would look like data loss to the user.
        let inMemory = CommandLine.arguments.contains("--uitest-inmemory")
        // CloudKit ASSERTS (not throws) when the entitlement is missing, so
        // sync must be gated up front: QRXCloudSyncEnabled mirrors whether the
        // iCloud entitlements are present in this build (stripped while on a
        // free personal team), and ubiquityIdentityToken confirms a signed-in
        // iCloud account.
        let entitled = (Bundle.main.object(forInfoDictionaryKey: "QRXCloudSyncEnabled") as? Bool) ?? false
        let syncAvailable = entitled && FileManager.default.ubiquityIdentityToken != nil
        do {
            containerResult = .success(try SharedStore.makeContainer(
                inMemory: inMemory,
                migrateLegacyStore: true,
                syncEnabled: !inMemory && syncAvailable
            ))
        } catch {
            // CloudKit mirroring can be unavailable (missing entitlement on a
            // personal dev team, or the user is signed out of iCloud). Opening
            // the SAME local store without sync is correct degradation — same
            // file, same data — not the in-memory data-loss case above.
            do {
                containerResult = .success(try SharedStore.makeContainer(
                    inMemory: inMemory,
                    migrateLegacyStore: true,
                    syncEnabled: false
                ))
            } catch {
                containerResult = .failure(error)
            }
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
