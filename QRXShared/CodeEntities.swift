import AppIntents
import Foundation
import SwiftData

/// Read-only fetches against the shared store, used by widget timelines and
/// App Intents in whichever process they run.
nonisolated enum CodeFetch {
    static func allCodes() -> [SavedCode] {
        guard let container = try? SharedStore.makeContainer() else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SavedCode>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let codes = (try? context.fetch(descriptor)) ?? []
        // Pinned first, then most recently updated.
        return codes.sorted { ($0.pinned ? 0 : 1, $1.updatedAt) < ($1.pinned ? 0 : 1, $0.updatedAt) }
    }

    static func code(id: UUID?) -> SavedCode? {
        let codes = allCodes()
        guard let id else { return codes.first }
        return codes.first { $0.id == id } ?? codes.first
    }
}

/// A saved code as an App Intents entity — powers the widget's code picker
/// and the "Show Saved QR Code" shortcut.
struct CodeEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Saved Code"
    static let defaultQuery = CodeQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(code: SavedCode) {
        self.id = code.id
        self.name = code.name
    }
}

struct CodeQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CodeEntity] {
        CodeFetch.allCodes().filter { identifiers.contains($0.id) }.map(CodeEntity.init)
    }

    func suggestedEntities() async throws -> [CodeEntity] {
        CodeFetch.allCodes().map(CodeEntity.init)
    }

    func defaultResult() async -> CodeEntity? {
        CodeFetch.allCodes().first.map(CodeEntity.init)
    }
}
