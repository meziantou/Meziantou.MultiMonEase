import AppKit
import ApplicationServices
import Foundation
import Security

public final class PermissionsManager {
    public static let shared = PermissionsManager()

    public var onPermissionChange: ((Bool) -> Void)?

    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var lastKnownState: Bool

    public init(pollInterval: TimeInterval = 2.0) {
        self.pollInterval = pollInterval
        lastKnownState = AXIsProcessTrusted()
    }

    public func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public func requestPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logPermissionState(context: "request", trusted: trusted, includeRecoveryHint: !trusted)
        return trusted
    }

    public func startMonitoring() {
        stopMonitoring()
        lastKnownState = isTrusted()
        logPermissionState(context: "monitor-start", trusted: lastKnownState, includeRecoveryHint: !lastKnownState)

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForStateChange()
        }

        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func checkForStateChange() {
        let trusted = isTrusted()
        guard trusted != lastKnownState else { return }

        lastKnownState = trusted
        logPermissionState(context: "state-change", trusted: trusted, includeRecoveryHint: !trusted)
        onPermissionChange?(trusted)
    }

    private func logPermissionState(context: StaticString, trusted: Bool, includeRecoveryHint: Bool) {
        AppLogger.permissions.info(
            "[\(context, privacy: .public)] Accessibility trusted=\(trusted, privacy: .public); identity=\(self.runtimeIdentityDescription(), privacy: .public)"
        )

        guard includeRecoveryHint else { return }
        AppLogger.permissions.notice(
            "Accessibility is not trusted. If System Settings already shows MultiMonEase as allowed, remove existing MultiMonEase entries and grant access again for this app instance."
        )
    }

    private func runtimeIdentityDescription() -> String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "<unknown>"
        let bundlePath = Bundle.main.bundleURL.path
        let executablePath = Bundle.main.executableURL?.path ?? ProcessInfo.processInfo.arguments.first ?? "<unknown>"

        return "bundleID=\(bundleIdentifier), bundlePath=\(bundlePath), executablePath=\(executablePath), signing=\(signingIdentityDescription())"
    }

    private func signingIdentityDescription() -> String {
        guard let executableURL = Bundle.main.executableURL else {
            return "unavailable(no-executable-url)"
        }

        var staticCode: SecStaticCode?
        let staticCodeStatus = SecStaticCodeCreateWithPath(executableURL as CFURL, [], &staticCode)
        guard staticCodeStatus == errSecSuccess, let staticCode else {
            return "unavailable(status=\(staticCodeStatus))"
        }

        var signingInfo: CFDictionary?
        let signingStatus = SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInfo)
        guard signingStatus == errSecSuccess, let info = signingInfo as? [String: Any] else {
            return "unavailable(status=\(signingStatus))"
        }

        let identifier = info[kSecCodeInfoIdentifier as String] as? String ?? "<unknown>"
        let teamIdentifier = info[kSecCodeInfoTeamIdentifier as String] as? String ?? "<none>"
        return "identifier=\(identifier), teamID=\(teamIdentifier)"
    }
}
