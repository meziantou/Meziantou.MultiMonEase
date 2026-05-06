import Foundation
import Testing
@testable import MultiMonEaseCore

@Test
func semanticVersionParsesPrefixAndPatch() {
    let version = SemanticVersion(rawValue: "v1.0.1")

    #expect(version != nil)
    #expect(version?.major == 1)
    #expect(version?.minor == 0)
    #expect(version?.patch == 1)
}

@Test
func semanticVersionComparisonIncludesPatch() {
    let current = SemanticVersion(rawValue: "1.0.0")
    let latest = SemanticVersion(rawValue: "1.0.1")

    #expect(current != nil)
    #expect(latest != nil)
    #expect(latest! > current!)
}

@Test
func semanticVersionNormalizesMissingComponents() {
    let twoComponents = SemanticVersion(rawValue: "1.2")
    let threeComponents = SemanticVersion(rawValue: "1.2.0")

    #expect(twoComponents != nil)
    #expect(threeComponents != nil)
    #expect(twoComponents == threeComponents)
}

@Test
func automaticUpdateCheckThrottleUsesFullDayInterval() {
    let suiteName = "UpdateCheckerTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Unable to create test user defaults suite")
        return
    }

    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let checker = UpdateChecker(defaults: defaults)
    let now = Date(timeIntervalSince1970: 10_000)

    #expect(checker.canRunAutomaticCheck(now: now))

    checker.markAutomaticCheck(now: now)

    #expect(!checker.canRunAutomaticCheck(now: now.addingTimeInterval(UpdateChecker.automaticCheckInterval - 1)))
    #expect(checker.canRunAutomaticCheck(now: now.addingTimeInterval(UpdateChecker.automaticCheckInterval)))
}
