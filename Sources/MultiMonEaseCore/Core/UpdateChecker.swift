import AppKit
import Foundation

struct SemanticVersion: Comparable, CustomStringConvertible, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutPrefix: String
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            withoutPrefix = String(trimmed.dropFirst())
        } else {
            withoutPrefix = trimmed
        }

        let coreVersion = String(withoutPrefix.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
            .split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? ""

        let rawParts = coreVersion.split(separator: ".", omittingEmptySubsequences: false)
        guard !rawParts.isEmpty, rawParts.count <= 3 else { return nil }

        var components: [Int] = []
        components.reserveCapacity(3)

        for rawPart in rawParts {
            guard let value = Int(rawPart) else { return nil }
            components.append(value)
        }

        while components.count < 3 {
            components.append(0)
        }

        major = components[0]
        minor = components[1]
        patch = components[2]
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }

        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }

        return lhs.patch < rhs.patch
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }
}

public final class UpdateChecker {
    public enum Trigger: Sendable {
        case automatic
        case manual
    }

    public static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    private struct LatestReleaseResponse: Decodable {
        let tagName: String
        let htmlURL: URL?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private struct LatestRelease {
        let version: SemanticVersion
        let releaseURL: URL
    }

    private enum UpdateCheckError: Error {
        case invalidHTTPResponse
        case unexpectedStatusCode(Int)
        case invalidCurrentVersion(String)
        case invalidLatestVersion(String)
    }

    private let defaults: UserDefaults
    private let bundle: Bundle
    private let session: URLSession
    private let nowProvider: @Sendable () -> Date

    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/meziantou/Meziantou.MultiMonEase/releases/latest")!
    private static let releasePageURL = URL(string: "https://github.com/meziantou/Meziantou.MultiMonEase/releases/latest")!
    internal static let lastAutomaticCheckDateKey = "MultiMonEase.updates.lastAutomaticCheckDate"

    public init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        session: URLSession = .shared,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.session = session
        self.nowProvider = nowProvider
    }

    public func checkForUpdates(trigger: Trigger) async {
        let now = nowProvider()
        if trigger == .automatic && !canRunAutomaticCheck(now: now) {
            return
        }

        do {
            let currentVersion = try currentSemanticVersion()
            let latestRelease = try await fetchLatestRelease()

            if latestRelease.version > currentVersion {
                await showUpdateAvailableAlert(currentVersion: currentVersion, latestRelease: latestRelease)
            } else if trigger == .manual {
                await showUpToDateAlert(version: currentVersion)
            }

            if trigger == .automatic {
                markAutomaticCheck(now: now)
            }
        } catch {
            AppLogger.updates.error("Unable to check for updates: \(String(describing: error), privacy: .public)")
            if trigger == .manual {
                await showCheckFailedAlert()
            }
        }
    }

    internal func canRunAutomaticCheck(now: Date) -> Bool {
        guard let lastCheckDate = defaults.object(forKey: Self.lastAutomaticCheckDateKey) as? Date else {
            return true
        }

        return now.timeIntervalSince(lastCheckDate) >= Self.automaticCheckInterval
    }

    internal func markAutomaticCheck(now: Date) {
        defaults.set(now, forKey: Self.lastAutomaticCheckDateKey)
    }

    private func currentSemanticVersion() throws -> SemanticVersion {
        let currentVersionString = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard let currentVersion = SemanticVersion(rawValue: currentVersionString) else {
            throw UpdateCheckError.invalidCurrentVersion(currentVersionString)
        }

        return currentVersion
    }

    private func fetchLatestRelease() async throws -> LatestRelease {
        let (data, response) = try await session.data(from: Self.latestReleaseAPIURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidHTTPResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw UpdateCheckError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let latestRelease = try JSONDecoder().decode(LatestReleaseResponse.self, from: data)
        guard let latestVersion = SemanticVersion(rawValue: latestRelease.tagName) else {
            throw UpdateCheckError.invalidLatestVersion(latestRelease.tagName)
        }

        return LatestRelease(
            version: latestVersion,
            releaseURL: latestRelease.htmlURL ?? Self.releasePageURL
        )
    }

    @MainActor
    private func showUpdateAvailableAlert(currentVersion: SemanticVersion, latestRelease: LatestRelease) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Update available"
        alert.informativeText = "MultiMonEase \(latestRelease.version) is available. You are running \(currentVersion)."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        NSApplication.shared.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(latestRelease.releaseURL)
        }
    }

    @MainActor
    private func showUpToDateAlert(version: SemanticVersion) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "You're up to date"
        alert.informativeText = "You are running the latest version (\(version))."
        alert.addButton(withTitle: "OK")

        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @MainActor
    private func showCheckFailedAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Unable to check for updates"
        alert.informativeText = "Please try again later."
        alert.addButton(withTitle: "OK")

        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
