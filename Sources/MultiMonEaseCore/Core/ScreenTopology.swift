import AppKit
import CoreGraphics
import Foundation

public enum DisplaySide: String, CaseIterable, Codable, Sendable {
    case left
    case right
    case top
    case bottom

    public var isVerticalBoundary: Bool {
        self == .left || self == .right
    }

    public func sharedCoordinate(for point: CGPoint) -> CGFloat {
        isVerticalBoundary ? point.y : point.x
    }
}

public struct DisplayInfo: Equatable, Sendable {
    public let id: CGDirectDisplayID
    public let frame: CGRect
    public let backingScaleFactor: CGFloat
    public let name: String
    public let horizontalDPI: CGFloat
    public let verticalDPI: CGFloat

    public var averageDPI: CGFloat {
        (horizontalDPI + verticalDPI) / 2
    }

    public init(
        id: CGDirectDisplayID,
        frame: CGRect,
        backingScaleFactor: CGFloat,
        name: String,
        horizontalDPI: CGFloat,
        verticalDPI: CGFloat
    ) {
        self.id = id
        self.frame = frame
        self.backingScaleFactor = backingScaleFactor
        self.name = name
        self.horizontalDPI = horizontalDPI
        self.verticalDPI = verticalDPI
    }
}

public struct EdgeAdjacency: Equatable, Hashable, Sendable {
    public let fromDisplay: CGDirectDisplayID
    public let toDisplay: CGDirectDisplayID
    public let side: DisplaySide
    public let overlapRange: ClosedRange<CGFloat>

    public var identifier: String {
        "\(fromDisplay)->\(toDisplay):\(side.rawValue)"
    }

    public init(
        fromDisplay: CGDirectDisplayID,
        toDisplay: CGDirectDisplayID,
        side: DisplaySide,
        overlapRange: ClosedRange<CGFloat>
    ) {
        self.fromDisplay = fromDisplay
        self.toDisplay = toDisplay
        self.side = side
        self.overlapRange = overlapRange
    }
}

public extension Notification.Name {
    static let screenTopologyDidChange = Notification.Name("MultiMonEase.screenTopologyDidChange")
}

public final class ScreenTopology {
    public private(set) var displays: [DisplayInfo] = []
    public private(set) var adjacencies: [EdgeAdjacency] = []
    public var onChange: (() -> Void)?

    private var callbackRegistered = false

    public init() {}

    public init(displays: [DisplayInfo], adjacencies: [EdgeAdjacency]? = nil) {
        self.displays = displays
        self.adjacencies = adjacencies ?? ScreenTopology.computeAdjacencies(displays: displays)
    }

    public func start() {
        refresh()
        guard !callbackRegistered else { return }

        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        callbackRegistered = true
    }

    public func stop() {
        guard callbackRegistered else { return }

        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        callbackRegistered = false
    }

    deinit {
        stop()
    }

    public func refresh() {
        let screens = NSScreen.screens
        let updatedDisplays = screens.compactMap(ScreenTopology.makeDisplayInfo)
        displays = updatedDisplays
        adjacencies = ScreenTopology.computeAdjacencies(displays: updatedDisplays)

        AppLogger.topology.info("Topology refreshed with \(updatedDisplays.count, privacy: .public) display(s) and \(self.adjacencies.count, privacy: .public) adjacency edge(s)")
        NotificationCenter.default.post(name: .screenTopologyDidChange, object: self)
        onChange?()
    }

    public func displaysSnapshot() -> [DisplayInfo] {
        displays
    }

    public func adjacenciesSnapshot() -> [EdgeAdjacency] {
        adjacencies
    }

    public func displayContaining(_ point: CGPoint) -> DisplayInfo? {
        displays.first { display in
            display.frame.insetBy(dx: -0.5, dy: -0.5).contains(point)
        }
    }

    public func display(for id: CGDirectDisplayID) -> DisplayInfo? {
        displays.first { $0.id == id }
    }

    public func adjacency(from displayID: CGDirectDisplayID, side: DisplaySide, coordinate: CGFloat) -> EdgeAdjacency? {
        adjacencies.first {
            $0.fromDisplay == displayID &&
                $0.side == side &&
                $0.overlapRange.contains(coordinate)
        }
    }

    public func adjacencies(from displayID: CGDirectDisplayID, side: DisplaySide) -> [EdgeAdjacency] {
        adjacencies.filter {
            $0.fromDisplay == displayID && $0.side == side
        }
    }

    public static func computeAdjacencies(displays: [DisplayInfo], tolerance: CGFloat = 1) -> [EdgeAdjacency] {
        var result: [EdgeAdjacency] = []

        for source in displays {
            for destination in displays where source.id != destination.id {
                if abs(source.frame.maxX - destination.frame.minX) <= tolerance,
                   let overlap = overlapRange(first: source.frame.minY...source.frame.maxY, second: destination.frame.minY...destination.frame.maxY)
                {
                    result.append(EdgeAdjacency(
                        fromDisplay: source.id,
                        toDisplay: destination.id,
                        side: .right,
                        overlapRange: overlap
                    ))
                }

                if abs(source.frame.minX - destination.frame.maxX) <= tolerance,
                   let overlap = overlapRange(first: source.frame.minY...source.frame.maxY, second: destination.frame.minY...destination.frame.maxY)
                {
                    result.append(EdgeAdjacency(
                        fromDisplay: source.id,
                        toDisplay: destination.id,
                        side: .left,
                        overlapRange: overlap
                    ))
                }

                if abs(source.frame.maxY - destination.frame.minY) <= tolerance,
                   let overlap = overlapRange(first: source.frame.minX...source.frame.maxX, second: destination.frame.minX...destination.frame.maxX)
                {
                    result.append(EdgeAdjacency(
                        fromDisplay: source.id,
                        toDisplay: destination.id,
                        side: .top,
                        overlapRange: overlap
                    ))
                }

                if abs(source.frame.minY - destination.frame.maxY) <= tolerance,
                   let overlap = overlapRange(first: source.frame.minX...source.frame.maxX, second: destination.frame.minX...destination.frame.maxX)
                {
                    result.append(EdgeAdjacency(
                        fromDisplay: source.id,
                        toDisplay: destination.id,
                        side: .bottom,
                        overlapRange: overlap
                    ))
                }
            }
        }

        return result
    }

    private static func overlapRange(first: ClosedRange<CGFloat>, second: ClosedRange<CGFloat>) -> ClosedRange<CGFloat>? {
        let lower = max(first.lowerBound, second.lowerBound)
        let upper = min(first.upperBound, second.upperBound)

        guard lower < upper else {
            return nil
        }

        return lower...upper
    }

    private static func makeDisplayInfo(from screen: NSScreen) -> DisplayInfo? {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        guard let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber else {
            return nil
        }

        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        let frame = CGDisplayBounds(displayID)
        let physicalSizeMM = CGDisplayScreenSize(displayID)

        let horizontalDPI: CGFloat
        if physicalSizeMM.width > 0 {
            horizontalDPI = CGFloat(CGDisplayPixelsWide(displayID)) / (physicalSizeMM.width / 25.4)
        } else {
            horizontalDPI = 110
        }

        let verticalDPI: CGFloat
        if physicalSizeMM.height > 0 {
            verticalDPI = CGFloat(CGDisplayPixelsHigh(displayID)) / (physicalSizeMM.height / 25.4)
        } else {
            verticalDPI = 110
        }

        return DisplayInfo(
            id: displayID,
            frame: frame,
            backingScaleFactor: screen.backingScaleFactor,
            name: screen.localizedName,
            horizontalDPI: horizontalDPI,
            verticalDPI: verticalDPI
        )
    }
}

private func displayReconfigurationCallback(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else { return }
    let topology = Unmanaged<ScreenTopology>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        topology.refresh()
    }
}
