import Foundation
import QRCore
import SwiftData
import Testing
@testable import QRX

@Suite("SavedCode persistence")
struct StoreTests {
    /// Each test gets its own isolated in-memory store.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SavedCode.self, configurations: config)
        return ModelContext(container)
    }

    @Test func writeAndLoadRoundTrip() throws {
        let context = try makeContext()

        let model = BuilderModel()
        model.contentType = .wifi
        model.wifiSSID = "PersistNet"
        model.wifiPassword = "secret"
        model.design.moduleShape = .circle
        model.design.eyeShape = .leaf
        model.hasFrame = true
        model.frameText = "JOIN"

        let code = SavedCode(name: "Office Wi-Fi")
        model.write(to: code)
        context.insert(code)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SavedCode>())
        #expect(fetched.count == 1)
        let saved = try #require(fetched.first)
        #expect(saved.name == "Office Wi-Fi")
        #expect(saved.typeLabel == "Wi-Fi")
        #expect(saved.payload == model.payload)

        let restored = BuilderModel()
        restored.load(from: saved)
        #expect(restored.payload == model.payload)
        #expect(restored.design == model.design)
        #expect(restored.frameText == "JOIN")
    }

    @Test func designDecodesFromStoredData() throws {
        let model = BuilderModel()
        model.design.moduleShape = .diamond
        let code = SavedCode(name: "X")
        model.write(to: code)
        #expect(code.design?.moduleShape == .diamond)
    }

    @Test func corruptDesignDataFailsGracefully() {
        let code = SavedCode(name: "Broken")
        code.designData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        #expect(code.design == nil)

        // Loading a corrupt record must not crash or clobber the builder.
        let model = BuilderModel()
        let before = model.design
        model.load(from: code)
        #expect(model.design == before)
    }

    @Test func writeUpdatesTimestamp() throws {
        let code = SavedCode(name: "Stamp")
        let original = code.updatedAt
        let model = BuilderModel()
        model.write(to: code)
        #expect(code.updatedAt >= original)
    }
}
