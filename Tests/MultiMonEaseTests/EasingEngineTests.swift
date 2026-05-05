import CoreGraphics
import Testing
@testable import MultiMonEaseCore

@Test
func remapAcrossRightEdgeStaysInsideDestination() {
    let engine = EasingEngine(
        parameters: EasingParameters(crossingDurationMS: 80, easeInCurve: .easeOut, preservePhysicalVelocity: true, antiOscillationCooldownMS: 50)
    )

    let source = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), dpi: 220)
    let destination = makeDisplay(id: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440), dpi: 110)
    let remapped = engine.remap(
        from: source,
        to: destination,
        crossingPoint: CGPoint(x: 1918, y: 540),
        velocity: CGVector(dx: 12, dy: 2),
        side: .right,
        overlapRange: 0...1080
    )

    #expect(remapped.x >= destination.frame.minX)
    #expect(remapped.x <= destination.frame.maxX)
    #expect(remapped.y >= 0)
    #expect(remapped.y <= 1080)
}

@Test
func remapPreservesSharedAxisWhenCrossingHorizontally() {
    let engine = EasingEngine(
        parameters: EasingParameters(crossingDurationMS: 80, easeInCurve: .easeOut, preservePhysicalVelocity: false, antiOscillationCooldownMS: 50)
    )

    let source = makeDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 1000), dpi: 160)
    let destination = makeDisplay(id: 2, frame: CGRect(x: 1000, y: 0, width: 1200, height: 1200), dpi: 160)
    let remapped = engine.remap(
        from: source,
        to: destination,
        crossingPoint: CGPoint(x: 999, y: 250),
        velocity: .zero,
        side: .right,
        overlapRange: 0...600
    )

    #expect(remapped.y == 250)
}

@Test
func remapKeepsSnappedOverlapEndpoint() {
    let engine = EasingEngine(
        parameters: EasingParameters(crossingDurationMS: 80, easeInCurve: .easeOut, preservePhysicalVelocity: false, antiOscillationCooldownMS: 50)
    )

    let source = makeDisplay(id: 1, frame: CGRect(x: 1000, y: 0, width: 1200, height: 1500), dpi: 160)
    let destination = makeDisplay(id: 2, frame: CGRect(x: 0, y: 250, width: 1000, height: 1000), dpi: 160)
    let remapped = engine.remap(
        from: source,
        to: destination,
        crossingPoint: CGPoint(x: 1001, y: 250),
        velocity: .zero,
        side: .left,
        overlapRange: 250...1250
    )

    #expect(remapped.y == 250)
}

private func makeDisplay(id: CGDirectDisplayID, frame: CGRect, dpi: CGFloat) -> DisplayInfo {
    DisplayInfo(
        id: id,
        frame: frame,
        backingScaleFactor: 2,
        name: "Display \(id)",
        horizontalDPI: dpi,
        verticalDPI: dpi
    )
}
