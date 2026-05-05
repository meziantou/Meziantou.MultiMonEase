import CoreGraphics
import Foundation

public struct BezierCurve: Sendable {
    public let p1x: CGFloat
    public let p1y: CGFloat
    public let p2x: CGFloat
    public let p2y: CGFloat

    public static let easeOut = BezierCurve(p1x: 0.25, p1y: 0.1, p2x: 0.25, p2y: 1)

    public init(p1x: CGFloat, p1y: CGFloat, p2x: CGFloat, p2y: CGFloat) {
        self.p1x = p1x
        self.p1y = p1y
        self.p2x = p2x
        self.p2y = p2y
    }

    public func value(at t: CGFloat) -> CGFloat {
        let t = min(max(t, 0), 1)
        let u = 1 - t
        return (3 * u * u * t * p1y) + (3 * u * t * t * p2y) + (t * t * t)
    }
}

public struct EasingParameters: Sendable {
    public var crossingDurationMS: Int
    public var easeInCurve: BezierCurve
    public var preservePhysicalVelocity: Bool
    public var antiOscillationCooldownMS: Int

    public init(
        crossingDurationMS: Int = 80,
        easeInCurve: BezierCurve = .easeOut,
        preservePhysicalVelocity: Bool = true,
        antiOscillationCooldownMS: Int = 50
    ) {
        self.crossingDurationMS = crossingDurationMS
        self.easeInCurve = easeInCurve
        self.preservePhysicalVelocity = preservePhysicalVelocity
        self.antiOscillationCooldownMS = antiOscillationCooldownMS
    }
}

public final class EasingEngine {
    public var parameters: EasingParameters

    public init(parameters: EasingParameters = EasingParameters()) {
        self.parameters = parameters
    }

    public func remap(
        from source: DisplayInfo,
        to destination: DisplayInfo,
        crossingPoint: CGPoint,
        velocity: CGVector,
        side: DisplaySide,
        overlapRange: ClosedRange<CGFloat>?
    ) -> CGPoint {
        var point = crossingAnchor(for: crossingPoint, destination: destination, side: side)
        let easedProgress = parameters.easeInCurve.value(at: 0.6)

        if side.isVerticalBoundary {
            let sourceRange = source.frame.minY...source.frame.maxY
            let destinationRange = destination.frame.minY...destination.frame.maxY
            point.y = mapCoordinate(crossingPoint.y, from: sourceRange, to: destinationRange)
        } else {
            let sourceRange = source.frame.minX...source.frame.maxX
            let destinationRange = destination.frame.minX...destination.frame.maxX
            point.x = mapCoordinate(crossingPoint.x, from: sourceRange, to: destinationRange)
        }

        if let overlapRange {
            if side.isVerticalBoundary {
                point.y = min(max(point.y, overlapRange.lowerBound), overlapRange.upperBound)
            } else {
                point.x = min(max(point.x, overlapRange.lowerBound), overlapRange.upperBound)
            }
        }

        if parameters.preservePhysicalVelocity {
            let sourceDPI = max(source.averageDPI, 1)
            let destinationDPI = max(destination.averageDPI, 1)
            let ratio = sourceDPI / destinationDPI
            let durationInSeconds = CGFloat(parameters.crossingDurationMS) / 1000

            point.x += velocity.dx * durationInSeconds * easedProgress * ratio
            point.y += velocity.dy * durationInSeconds * easedProgress * ratio
        }

        let destinationBounds = destination.frame.insetBy(dx: 1, dy: 1)
        point.x = min(max(point.x, destinationBounds.minX), destinationBounds.maxX)
        point.y = min(max(point.y, destinationBounds.minY), destinationBounds.maxY)
        return point
    }

    private func crossingAnchor(for point: CGPoint, destination: DisplayInfo, side: DisplaySide) -> CGPoint {
        switch side {
        case .left:
            return CGPoint(x: destination.frame.maxX - 1, y: point.y)
        case .right:
            return CGPoint(x: destination.frame.minX + 1, y: point.y)
        case .top:
            return CGPoint(x: point.x, y: destination.frame.minY + 1)
        case .bottom:
            return CGPoint(x: point.x, y: destination.frame.maxY - 1)
        }
    }

    private func mapCoordinate(_ value: CGFloat, from source: ClosedRange<CGFloat>, to destination: ClosedRange<CGFloat>) -> CGFloat {
        let sourceLength = max(source.upperBound - source.lowerBound, 1)
        let normalized = (value - source.lowerBound) / sourceLength
        return destination.lowerBound + (normalized * (destination.upperBound - destination.lowerBound))
    }
}
