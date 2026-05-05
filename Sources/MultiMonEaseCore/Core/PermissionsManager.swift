import AppKit
import ApplicationServices
import Foundation

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
        return AXIsProcessTrustedWithOptions(options)
    }

    public func startMonitoring() {
        stopMonitoring()
        lastKnownState = isTrusted()

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
        AppLogger.permissions.info("Accessibility permission changed to \(trusted, privacy: .public)")
        onPermissionChange?(trusted)
    }
}
