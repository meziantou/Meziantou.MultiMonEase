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
    private let cornerSnapThreshold: CGFloat = 24

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
        var adjustedCrossingPoint = currentPoint
        let adjacency: EdgeAdjacency

        if let directAdjacency = topology.adjacency(
            from: sourceDisplay.id,
            side: crossingSide,
            coordinate: sharedAxisCoordinate
        ) {
            adjacency = directAdjacency
        } else {
            let candidates = topology.adjacencies(from: sourceDisplay.id, side: crossingSide)
            guard let nearestAdjacency = nearestAdjacency(to: sharedAxisCoordinate, in: candidates) else {
                AppLogger.routing.debug(
                    "Blocked \(sourceDisplay.name, privacy: .public) via \(crossingSide.rawValue, privacy: .public): no adjacent display"
                )
                return Unmanaged.passUnretained(event)
            }

            let distance = distanceToRange(sharedAxisCoordinate, nearestAdjacency.overlapRange)
            guard distance <= cornerSnapThreshold else {
                AppLogger.routing.debug(
                    "Blocked \(sourceDisplay.name, privacy: .public) via \(crossingSide.rawValue, privacy: .public): outside overlap by \(distance, privacy: .public)"
                )
                return Unmanaged.passUnretained(event)
            }

            let snappedCoordinate = clamp(sharedAxisCoordinate, to: nearestAdjacency.overlapRange)
            adjustedCrossingPoint = point(currentPoint, byReplacingSharedCoordinateFor: crossingSide, with: snappedCoordinate)
            adjacency = nearestAdjacency

            AppLogger.routing.debug(
                "Corner-snap \(sourceDisplay.name, privacy: .public) via \(crossingSide.rawValue, privacy: .public) (\(sharedAxisCoordinate, privacy: .public) -> \(snappedCoordinate, privacy: .public))"
            )
        }

        guard let destinationDisplay = topology.display(for: adjacency.toDisplay) else {
            return Unmanaged.passUnretained(event)
        }

        guard settings.isEnabled(for: adjacency) else {
            return Unmanaged.passUnretained(event)
        }

        easing.parameters = settings.easingParameters
        let remappedPoint = easing.remap(
            from: sourceDisplay,
            to: destinationDisplay,
            crossingPoint: adjustedCrossingPoint,
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

    private func nearestAdjacency(to coordinate: CGFloat, in candidates: [EdgeAdjacency]) -> EdgeAdjacency? {
        candidates.min { lhs, rhs in
            distanceToRange(coordinate, lhs.overlapRange) < distanceToRange(coordinate, rhs.overlapRange)
        }
    }

    private func distanceToRange(_ coordinate: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
        if range.contains(coordinate) {
            return 0
        }

        if coordinate < range.lowerBound {
            return range.lowerBound - coordinate
        }

        return coordinate - range.upperBound
    }

    private func clamp(_ coordinate: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(coordinate, range.lowerBound), range.upperBound)
    }

    private func point(_ point: CGPoint, byReplacingSharedCoordinateFor side: DisplaySide, with coordinate: CGFloat) -> CGPoint {
        if side.isVerticalBoundary {
            return CGPoint(x: point.x, y: coordinate)
        }

        return CGPoint(x: coordinate, y: point.y)
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
