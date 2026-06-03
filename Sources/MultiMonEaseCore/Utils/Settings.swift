import Combine
import Foundation

public struct SettingsSnapshot: Codable, Sendable {
    public var isEnabled = true
    public var crossingDurationMS = 80
    public var preservePhysicalVelocity = true
    public var antiOscillationCooldownMS = 50
    public var edgeResistanceDistancePx = 12.0
    public var disabledEdges: Set<String> = []
}

public final class Settings: ObservableObject {
    public static let shared = Settings()

    @Published public var isEnabled: Bool {
        didSet { save() }
    }

    @Published public var crossingDurationMS: Int {
        didSet {
            let clampedValue = min(max(crossingDurationMS, 30), 200)
            if crossingDurationMS != clampedValue {
                crossingDurationMS = clampedValue
                return
            }
            save()
        }
    }

    @Published public var preservePhysicalVelocity: Bool {
        didSet { save() }
    }

    @Published public var antiOscillationCooldownMS: Int {
        didSet {
            let clampedValue = min(max(antiOscillationCooldownMS, 10), 300)
            if antiOscillationCooldownMS != clampedValue {
                antiOscillationCooldownMS = clampedValue
                return
            }
            save()
        }
    }

    @Published public var edgeResistanceDistancePx: Double {
        didSet {
            let clampedValue = min(max(edgeResistanceDistancePx, 0), 100)
            if edgeResistanceDistancePx != clampedValue {
                edgeResistanceDistancePx = clampedValue
                return
            }
            save()
        }
    }

    @Published public var disabledEdges: Set<String> {
        didSet { save() }
    }

    public var easingParameters: EasingParameters {
        EasingParameters(
            crossingDurationMS: crossingDurationMS,
            easeInCurve: .easeOut,
            preservePhysicalVelocity: preservePhysicalVelocity,
            antiOscillationCooldownMS: antiOscillationCooldownMS
        )
    }

    private let defaults: UserDefaults
    private let storageKey = "MultiMonEase.settings"
    private var isLoading = false

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let snapshot = Settings.loadSnapshot(defaults: defaults, storageKey: storageKey)
        isEnabled = snapshot.isEnabled
        crossingDurationMS = snapshot.crossingDurationMS
        preservePhysicalVelocity = snapshot.preservePhysicalVelocity
        antiOscillationCooldownMS = snapshot.antiOscillationCooldownMS
        edgeResistanceDistancePx = snapshot.edgeResistanceDistancePx
        disabledEdges = snapshot.disabledEdges
    }

    public func isEnabled(for adjacency: EdgeAdjacency) -> Bool {
        !disabledEdges.contains(adjacency.identifier)
    }

    public func setEdgeEnabled(_ enabled: Bool, for adjacency: EdgeAdjacency) {
        let identifier = adjacency.identifier
        if enabled {
            disabledEdges.remove(identifier)
        } else {
            disabledEdges.insert(identifier)
        }
    }

    public func resetToDefaults() {
        isLoading = true
        isEnabled = true
        crossingDurationMS = 80
        preservePhysicalVelocity = true
        antiOscillationCooldownMS = 50
        edgeResistanceDistancePx = 12
        disabledEdges = []
        isLoading = false
        save()
    }

    private func save() {
        guard !isLoading else { return }

        let snapshot = SettingsSnapshot(
            isEnabled: isEnabled,
            crossingDurationMS: crossingDurationMS,
            preservePhysicalVelocity: preservePhysicalVelocity,
            antiOscillationCooldownMS: antiOscillationCooldownMS,
            edgeResistanceDistancePx: edgeResistanceDistancePx,
            disabledEdges: disabledEdges
        )

        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: storageKey)
        } catch {
            AppLogger.app.error("Unable to save settings: \(String(describing: error), privacy: .public)")
        }
    }

    private static func loadSnapshot(defaults: UserDefaults, storageKey: String) -> SettingsSnapshot {
        guard
            let data = defaults.data(forKey: storageKey),
            let snapshot = try? JSONDecoder().decode(SettingsSnapshot.self, from: data)
        else {
            return SettingsSnapshot()
        }

        return snapshot
    }
}
