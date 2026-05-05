import CoreGraphics
import Testing
@testable import MultiMonEaseCore

@Test
func adjacencyDetectionFindsHorizontalAndVerticalEdges() {
    let left = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
    let right = makeDisplay(id: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440))
    let top = makeDisplay(id: 3, frame: CGRect(x: 0, y: 1080, width: 1920, height: 1080))

    let adjacencies = ScreenTopology.computeAdjacencies(displays: [left, right, top])

    let hasRight = adjacencies.contains { $0.fromDisplay == 1 && $0.toDisplay == 2 && $0.side == .right }
    let hasLeft = adjacencies.contains { $0.fromDisplay == 2 && $0.toDisplay == 1 && $0.side == .left }
    let hasTop = adjacencies.contains { $0.fromDisplay == 1 && $0.toDisplay == 3 && $0.side == .top }
    let hasBottom = adjacencies.contains { $0.fromDisplay == 3 && $0.toDisplay == 1 && $0.side == .bottom }

    #expect(hasRight)
    #expect(hasLeft)
    #expect(hasTop)
    #expect(hasBottom)
}

@Test
func adjacencyDetectionHonorsOverlap() {
    let a = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
    let b = makeDisplay(id: 2, frame: CGRect(x: 1000, y: 950, width: 1000, height: 1000))

    let adjacencies = ScreenTopology.computeAdjacencies(displays: [a, b])
    let edge = adjacencies.first(where: { $0.fromDisplay == 1 && $0.toDisplay == 2 && $0.side == .right })

    #expect(edge != nil)
    #expect(edge?.overlapRange.lowerBound == 950)
    #expect(edge?.overlapRange.upperBound == 1000)
}

private func makeDisplay(id: CGDirectDisplayID, frame: CGRect) -> DisplayInfo {
    DisplayInfo(
        id: id,
        frame: frame,
        backingScaleFactor: 2,
        name: "Display \(id)",
        horizontalDPI: 220,
        verticalDPI: 220
    )
}
