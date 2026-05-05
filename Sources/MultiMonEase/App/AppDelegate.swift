import AppKit
import MultiMonEaseCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let permissionsManager = PermissionsManager.shared
    private let topology = ScreenTopology()
    private let easingEngine = EasingEngine()
    private let eventTapController = EventTapController()

    private lazy var router = CursorRouter(
        topology: topology,
        easing: easingEngine,
        settings: settings
    )

    private var statusBarController: StatusBarController?
    private var preferencesWindowController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        topology.start()

        eventTapController.router = router
        preferencesWindowController = PreferencesWindowController(settings: settings, topology: topology)
        statusBarController = StatusBarController(
            settings: settings,
            permissionsManager: permissionsManager,
            topology: topology,
            showPreferences: { [weak self] in
                self?.preferencesWindowController?.showWindow()
            }
        )

        permissionsManager.onPermissionChange = { [weak self] isTrusted in
            self?.handlePermissionChange(isTrusted)
        }
        permissionsManager.startMonitoring()
        handlePermissionChange(permissionsManager.isTrusted())
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionsManager.stopMonitoring()
        eventTapController.stop()
        topology.stop()
    }

    private func handlePermissionChange(_ isTrusted: Bool) {
        if isTrusted {
            startEventTapIfNeeded()
        } else {
            eventTapController.stop()
            _ = permissionsManager.requestPermission()
        }

        statusBarController?.refreshState()
    }

    private func startEventTapIfNeeded() {
        do {
            try eventTapController.start()
        } catch {
            AppLogger.app.error("Unable to start event tap: \(String(describing: error), privacy: .public)")
        }
    }
}
