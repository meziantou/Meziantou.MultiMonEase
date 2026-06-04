import AppKit
import SwiftUI

public final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let settings: Settings
    private let topology: ScreenTopology
    private var window: NSWindow?

    public init(settings: Settings, topology: ScreenTopology) {
        self.settings = settings
        self.topology = topology
    }

    public func showWindow() {
        let window = window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let rootView = PreferencesRootView(settings: settings, topology: topology)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "MultiMonEase Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 540, height: 440))
        window.center()
        window.delegate = self
        return window
    }
}

private struct PreferencesRootView: View {
    @ObservedObject var settings: Settings
    let topology: ScreenTopology

    @State private var adjacencies: [EdgeAdjacency] = []
    @State private var cursorLocation: CGPoint = .zero

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Enable easing", isOn: $settings.isEnabled)

            VStack(alignment: .leading, spacing: 8) {
                Text("Crossing duration: \(settings.crossingDurationMS) ms")
                Slider(
                    value: Binding(
                        get: { Double(settings.crossingDurationMS) },
                        set: { settings.crossingDurationMS = Int($0.rounded()) }
                    ),
                    in: 30...200,
                    step: 1
                )
            }

            Toggle("Preserve physical velocity", isOn: $settings.preservePhysicalVelocity)

            VStack(alignment: .leading, spacing: 8) {
                Text("Edge resistance: \(Int(settings.edgeResistanceDistancePx.rounded())) px")
                Slider(
                    value: $settings.edgeResistanceDistancePx,
                    in: 0...200,
                    step: 1
                )
                Text("Require extra movement at a display border before crossing to reduce accidental jumps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Per-edge enablement")
                    .font(.headline)

                if adjacencies.isEmpty {
                    Text("No adjacent display edges detected.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(adjacencies, id: \.identifier) { adjacency in
                                Toggle(adjacencyLabel(adjacency), isOn: Binding(
                                    get: { settings.isEnabled(for: adjacency) },
                                    set: { settings.setEdgeEnabled($0, for: adjacency) }
                                ))
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }

            HStack {
                Text("Cursor: x \(Int(cursorLocation.x)), y \(Int(cursorLocation.y))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .padding(16)
        .onAppear {
            refresh()
        }
        .onReceive(timer) { _ in
            refresh()
        }
    }

    private func refresh() {
        adjacencies = topology.adjacenciesSnapshot()
        cursorLocation = NSEvent.mouseLocation
    }

    private func adjacencyLabel(_ adjacency: EdgeAdjacency) -> String {
        let sourceName = topology.display(for: adjacency.fromDisplay)?.name ?? "Display \(adjacency.fromDisplay)"
        let destinationName = topology.display(for: adjacency.toDisplay)?.name ?? "Display \(adjacency.toDisplay)"
        return "\(sourceName) → \(destinationName) [\(adjacency.side.rawValue)]"
    }
}
