import AppKit
import Combine
import Foundation
import ServiceManagement

public final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: Settings
    private let permissionsManager: PermissionsManager
    private let topology: ScreenTopology
    private let showPreferences: () -> Void
    private var cancellables = Set<AnyCancellable>()

    private let menu = NSMenu()
    private let enabledItem = NSMenuItem(title: "Easing enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
    private let permissionsItem = NSMenuItem(title: "Permissions", action: #selector(handlePermissions), keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let aboutItem = NSMenuItem(title: "About", action: #selector(openAbout), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

    public init(
        settings: Settings,
        permissionsManager: PermissionsManager,
        topology: ScreenTopology,
        showPreferences: @escaping () -> Void
    ) {
        self.settings = settings
        self.permissionsManager = permissionsManager
        self.topology = topology
        self.showPreferences = showPreferences
        super.init()

        configureStatusItem()
        configureMenu()
        bindState()
        refreshState()
    }

    public func refreshState() {
        enabledItem.state = settings.isEnabled ? .on : .off
        let trusted = permissionsManager.isTrusted()
        permissionsItem.title = trusted ? "Permissions: Granted ✓" : "Permissions: Required ⚠"
        permissionsItem.isEnabled = !trusted

        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        launchAtLoginItem.isEnabled = true

        let adjacencyCount = topology.adjacenciesSnapshot().count
        statusItem.button?.toolTip = "MultiMonEase (\(adjacencyCount) edge\(adjacencyCount == 1 ? "" : "s"))"
    }

    public func menuWillOpen(_ menu: NSMenu) {
        refreshState()
    }

    private func configureStatusItem() {
        if let image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "MultiMonEase") {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "MME"
        }

        statusItem.button?.imagePosition = .imageOnly
    }

    private func configureMenu() {
        menu.delegate = self

        [enabledItem, preferencesItem, permissionsItem, .separator(), launchAtLoginItem, aboutItem, quitItem]
            .forEach {
                $0.target = self
                menu.addItem($0)
            }

        statusItem.menu = menu
    }

    private func bindState() {
        settings.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .screenTopologyDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshState()
            }
            .store(in: &cancellables)
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
    }

    @objc private func openPreferences() {
        showPreferences()
    }

    @objc private func handlePermissions() {
        _ = permissionsManager.requestPermission()
        permissionsManager.openSystemSettings()
        refreshState()
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }

        do {
            if isLaunchAtLoginEnabled() {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            AppLogger.app.error("Unable to update launch-at-login state: \(String(describing: error), privacy: .public)")
        }

        refreshState()
    }

    @objc private func openAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }
}
