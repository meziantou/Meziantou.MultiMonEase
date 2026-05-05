import CoreGraphics
import Foundation

public final class CursorRouter: CursorRouting {
    public let topology: ScreenTopology
    public let easing: EasingEngine
    public var settings: Settings

    private enum CrossingState {
        case idle
        case justCrossed(Date)
    }

    private var crossingState: CrossingState = .idle
    private var deltaSamples: [CGVector] = []
    private let maxDeltaSamples = 8

    public init(topology: ScreenTopology, easing: EasingEngine, settings: Settings) {
        self.topology = topology
        self.easing = easing
        self.settings = settings
    }

    public func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        guard settings.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        if isWithinAntiOscillationWindow() {
            return Unmanaged.passUnretained(event)
        }

        let currentPoint = event.location
        let delta = CGVector(
            dx: event.getDoubleValueField(.mouseEventDeltaX),
            dy: event.getDoubleValueField(.mouseEventDeltaY)
        )
        append(delta: delta)

        guard let sourceDisplay = topology.displayContaining(currentPoint) else {
            return Unmanaged.passUnretained(event)
        }

        let intendedPoint = CGPoint(x: currentPoint.x + delta.dx, y: currentPoint.y + delta.dy)
        if sourceDisplay.frame.contains(intendedPoint) {
            return Unmanaged.passUnretained(event)
        }

        guard let crossingSide = sideForCrossing(from: sourceDisplay.frame, to: intendedPoint) else {
            return Unmanaged.passUnretained(event)
        }

        let sharedAxisCoordinate = crossingSide.sharedCoordinate(for: currentPoint)
        guard
            let adjacency = topology.adjacency(
                from: sourceDisplay.id,
                side: crossingSide,
                coordinate: sharedAxisCoordinate
            ),
            let destinationDisplay = topology.display(for: adjacency.toDisplay)
        else {
            return Unmanaged.passUnretained(event)
        }

        guard settings.isEnabled(for: adjacency) else {
            return Unmanaged.passUnretained(event)
        }

        easing.parameters = settings.easingParameters
        let remappedPoint = easing.remap(
            from: sourceDisplay,
            to: destinationDisplay,
            crossingPoint: currentPoint,
            velocity: averageVelocity(),
            side: crossingSide,
            overlapRange: adjacency.overlapRange
        )

        prepareWarpBehavior()
        CGWarpMouseCursorPosition(remappedPoint)
        postSyntheticMove(at: remappedPoint)
        crossingState = .justCrossed(Date())

        AppLogger.routing.debug(
            "Crossed \(sourceDisplay.name, privacy: .public) -> \(destinationDisplay.name, privacy: .public) via \(crossingSide.rawValue, privacy: .public)"
        )

        return nil
    }

    private func append(delta: CGVector) {
        deltaSamples.append(delta)
        if deltaSamples.count > maxDeltaSamples {
            deltaSamples.removeFirst(deltaSamples.count - maxDeltaSamples)
        }
    }

    private func averageVelocity() -> CGVector {
        guard !deltaSamples.isEmpty else { return .zero }
        let sum = deltaSamples.reduce(CGVector.zero) { partial, sample in
            CGVector(dx: partial.dx + sample.dx, dy: partial.dy + sample.dy)
        }

        let count = CGFloat(deltaSamples.count)
        return CGVector(dx: sum.dx / count, dy: sum.dy / count)
    }

    private func sideForCrossing(from sourceFrame: CGRect, to intendedPoint: CGPoint) -> DisplaySide? {
        if intendedPoint.x < sourceFrame.minX {
            return .left
        }
        if intendedPoint.x > sourceFrame.maxX {
            return .right
        }
        if intendedPoint.y > sourceFrame.maxY {
            return .top
        }
        if intendedPoint.y < sourceFrame.minY {
            return .bottom
        }
        return nil
    }

    private func isWithinAntiOscillationWindow() -> Bool {
        guard case let .justCrossed(timestamp) = crossingState else {
            return false
        }

        let cooldownInSeconds = Double(settings.antiOscillationCooldownMS) / 1000
        if Date().timeIntervalSince(timestamp) < cooldownInSeconds {
            return true
        }

        crossingState = .idle
        return false
    }

    private func prepareWarpBehavior() {
        if let eventSource = CGEventSource(stateID: .combinedSessionState) {
            eventSource.localEventsSuppressionInterval = 0
        }
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    private func postSyntheticMove(at point: CGPoint) {
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return
        }

        moveEvent.setIntegerValueField(.mouseEventDeltaX, value: 0)
        moveEvent.setIntegerValueField(.mouseEventDeltaY, value: 0)
        moveEvent.post(tap: .cghidEventTap)
    }
}
