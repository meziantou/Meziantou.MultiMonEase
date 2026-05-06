import CoreGraphics
import Foundation

public protocol CursorRouting: AnyObject {
    func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>?
}

public enum EventTapControllerError: Error {
    case unableToCreateTap
}

public final class EventTapController {
    public weak var router: CursorRouting?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    public init() {}

    public func start() throws {
        guard !isRunning else { return }

        let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: eventTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            throw EventTapControllerError.unableToCreateTap
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = runLoopSource
        isRunning = true
        AppLogger.app.info("Event tap started")
    }

    public func stop() {
        guard isRunning else { return }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let tap {
            CFMachPortInvalidate(tap)
            self.tap = nil
        }

        isRunning = false
        AppLogger.app.info("Event tap stopped")
    }

    deinit {
        stop()
    }

    func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
                AppLogger.app.notice("Event tap re-enabled after disable event")
            }
            return Unmanaged.passUnretained(event)
        }

        return router?.handle(event: event, type: type) ?? Unmanaged.passUnretained(event)
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(proxy: proxy, type: type, event: event)
}
