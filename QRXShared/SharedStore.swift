import Foundation
import SwiftData

/// The SwiftData store lives in the App Group container so the widget
/// extension can read saved codes. Both the app and QRXWidgets use this.
enum SharedStore {
    static let appGroupID = "group.com.brianf.QRX"

    static func storeURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw StoreError.appGroupUnavailable
        }
        return container.appendingPathComponent("QRX.store")
    }

    /// - Parameters:
    ///   - inMemory: isolated throwaway store (UI tests).
    ///   - migrateLegacyStore: app-only — one-time copy of the pre-App-Group
    ///     store from Application Support into the group container.
    static func makeContainer(inMemory: Bool = false, migrateLegacyStore: Bool = false) throws -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: SavedCode.self, configurations: config)
        }
        let url = try storeURL()
        if migrateLegacyStore {
            migrateLegacyStoreIfNeeded(to: url)
        }
        let config = ModelConfiguration(url: url)
        return try ModelContainer(for: SavedCode.self, configurations: config)
    }

    /// Copies the old default-location store into the App Group container,
    /// once, if the new store doesn't exist yet. Never deletes the original.
    private static func migrateLegacyStoreIfNeeded(to newURL: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: newURL.path) else { return }
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let legacyURL = appSupport.appendingPathComponent("default.store")
        guard fm.fileExists(atPath: legacyURL.path) else { return }
        for suffix in ["", "-shm", "-wal"] {
            let from = legacyURL.path + suffix
            let to = newURL.path + suffix
            if fm.fileExists(atPath: from) {
                try? fm.copyItem(atPath: from, toPath: to)
            }
        }
    }

    enum StoreError: LocalizedError {
        case appGroupUnavailable

        var errorDescription: String? {
            "The shared storage container is unavailable."
        }
    }
}
