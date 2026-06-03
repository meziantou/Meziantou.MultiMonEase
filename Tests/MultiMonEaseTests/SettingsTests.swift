import Foundation
import Testing
@testable import MultiMonEaseCore

@Test
func settingsLoadMissingEdgeResistanceUsesDefault() {
    let suiteName = "SettingsTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Unable to create test user defaults suite")
        return
    }

    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let legacySnapshot = LegacySettingsSnapshot(
        isEnabled: true,
        crossingDurationMS: 80,
        preservePhysicalVelocity: true,
        antiOscillationCooldownMS: 50,
        disabledEdges: []
    )

    do {
        let data = try JSONEncoder().encode(legacySnapshot)
        defaults.set(data, forKey: "MultiMonEase.settings")
    } catch {
        Issue.record("Unable to encode legacy snapshot")
        return
    }

    let settings = Settings(defaults: defaults)

    #expect(settings.edgeResistanceDistancePx == 12)
}

@Test
func settingsPersistsEdgeResistanceDistance() {
    let suiteName = "SettingsTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Unable to create test user defaults suite")
        return
    }

    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = Settings(defaults: defaults)
    settings.edgeResistanceDistancePx = 21

    let reloaded = Settings(defaults: defaults)
    #expect(reloaded.edgeResistanceDistancePx == 21)
}

private struct LegacySettingsSnapshot: Codable {
    let isEnabled: Bool
    let crossingDurationMS: Int
    let preservePhysicalVelocity: Bool
    let antiOscillationCooldownMS: Int
    let disabledEdges: Set<String>
}
