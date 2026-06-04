import CoreGraphics
import Foundation
import Testing
@testable import MultiMonEaseCore

@Test
func rightCrossingRequiresAccumulatedEdgeResistance() {
    let suiteName = "CursorRouterTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Unable to create test user defaults suite")
        return
    }

    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = Settings(defaults: defaults)
    settings.edgeResistanceDistancePx = 12

    let displays = [
        makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
        makeDisplay(id: 2, frame: CGRect(x: 100, y: 0, width: 100, height: 100)),
    ]

    let topology = ScreenTopology(displays: displays)
    let easing = EasingEngine()
    var warpedPoints: [CGPoint] = []

    let router = CursorRouter(
        topology: topology,
        easing: easing,
        settings: settings,
        prepareWarpAction: {},
        warpCursorAction: { warpedPoints.append($0) },
        postSyntheticMoveAction: { _ in }
    )

    let first = makeMouseMovedEvent(location: CGPoint(x: 99, y: 50), dx: 4, dy: 0)
    let second = makeMouseMovedEvent(location: CGPoint(x: 99, y: 50), dx: 4, dy: 0)
    let third = makeMouseMovedEvent(location: CGPoint(x: 99, y: 50), dx: 4, dy: 0)

    let firstResult = router.handle(event: first, type: .mouseMoved)
    let secondResult = router.handle(event: second, type: .mouseMoved)
    let thirdResult = router.handle(event: third, type: .mouseMoved)

    #expect(firstResult != nil)
    #expect(secondResult != nil)
    #expect(thirdResult == nil)
    #expect(warpedPoints.count == 1)
}

@Test
func reversingDirectionResetsAccumulatedResistance() {
    let suiteName = "CursorRouterTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Unable to create test user defaults suite")
        return
    }

    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = Settings(defaults: defaults)
    settings.edgeResistanceDistancePx = 12

    let displays = [
        makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
        makeDisplay(id: 2, frame: CGRect(x: 100, y: 0, width: 100, height: 100)),
    ]

    let topology = ScreenTopology(displays: displays)
    let easing = EasingEngine()
    var warpedPoints: [CGPoint] = []

    let router = CursorRouter(
        topology: topology,
        easing: easing,
        settings: settings,
        prepareWarpAction: {},
        warpCursorAction: { warpedPoints.append($0) },
        postSyntheticMoveAction: { _ in }
    )

    let pushRight = makeMouseMovedEvent(location: CGPoint(x: 99, y: 50), dx: 6, dy: 0)
    let moveInside = makeMouseMovedEvent(location: CGPoint(x: 99, y: 50), dx: -1, dy: 0)
    let pushRightAgain = makeMouseMovedEvent(location: CGPoint(x: 99, y: 50), dx: 6, dy: 0)

    let firstResult = router.handle(event: pushRight, type: .mouseMoved)
    let resetResult = router.handle(event: moveInside, type: .mouseMoved)
    let secondResult = router.handle(event: pushRightAgain, type: .mouseMoved)

    #expect(firstResult != nil)
    #expect(resetResult != nil)
    #expect(secondResult != nil)
    #expect(warpedPoints.isEmpty)
}

@Test
func disabledEdgeStillPreventsCrossingAfterResistance() {
    let suiteName = "CursorRouterTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Unable to create test user defaults suite")
        return
    }

    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = Settings(defaults: defaults)
    settings.edgeResistanceDistancePx = 4

    let displays = [
        makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
        makeDisplay(id: 2, frame: CGRect(x: 100, y: 0, width: 100, height: 100)),
    ]

    let topology = ScreenTopology(displays: displays)
    guard let adjacency = topology.adjacency(from: 1, side: .right, coordinate: 50) else {
        Issue.record("Expected right adjacency")
        return
    }

    settings.setEdgeEnabled(false, for: adjacency)

    let easing = EasingEngine()
    var warpedPoints: [CGPoint] = []

    let router = CursorRouter(
        topology: topology,
        easing: easing,
        settings: settings,
        prepareWarpAction: {},
        warpCursorAction: { warpedPoints.append($0) },
        postSyntheticMoveAction: { _ in }
    )

    let event = makeMouseMovedEvent(location: CGPoint(x: 99, y: 50), dx: 5, dy: 0)
    let result = router.handle(event: event, type: .mouseMoved)

    #expect(result != nil)
    #expect(warpedPoints.isEmpty)
}

@Test
func antiOscillationStillBlocksImmediateRecross() {
    let suiteName = "CursorRouterTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Unable to create test user defaults suite")
        return
    }

    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let settings = Settings(defaults: defaults)
    settings.edgeResistanceDistancePx = 0
    settings.antiOscillationCooldownMS = 300

    let displays = [
        makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
        makeDisplay(id: 2, frame: CGRect(x: 100, y: 0, width: 100, height: 100)),
    ]

    let topology = ScreenTopology(displays: displays)
    let easing = EasingEngine()
    var warpedPoints: [CGPoint] = []

    let router = CursorRouter(
        topology: topology,
        easing: easing,
        settings: settings,
        prepareWarpAction: {},
        warpCursorAction: { warpedPoints.append($0) },
        postSyntheticMoveAction: { _ in }
    )

    let crossRight = makeMouseMovedEvent(location: CGPoint(x: 99, y: 50), dx: 5, dy: 0)
    let crossLeftImmediately = makeMouseMovedEvent(location: CGPoint(x: 101, y: 50), dx: -5, dy: 0)

    let firstResult = router.handle(event: crossRight, type: .mouseMoved)
    let secondResult = router.handle(event: crossLeftImmediately, type: .mouseMoved)

    #expect(firstResult == nil)
    #expect(secondResult != nil)
    #expect(warpedPoints.count == 1)
}

private func makeDisplay(id: CGDirectDisplayID, frame: CGRect) -> DisplayInfo {
    DisplayInfo(
        id: id,
        frame: frame,
        backingScaleFactor: 2,
        name: "Display \(id)",
        horizontalDPI: 160,
        verticalDPI: 160
    )
}

private func makeMouseMovedEvent(location: CGPoint, dx: Double, dy: Double) -> CGEvent {
    guard let event = CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: location,
        mouseButton: .left
    ) else {
        fatalError("Unable to create mouse event")
    }

    event.setDoubleValueField(.mouseEventDeltaX, value: dx)
    event.setDoubleValueField(.mouseEventDeltaY, value: dy)
    return event
}
