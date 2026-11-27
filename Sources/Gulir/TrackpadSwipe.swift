import AppKit
import GulirCore

/// ⌥ + swipe 2 jari horizontal → pindah fokus kolom.
/// Memakai CGEventTap (API publik); cukup dengan izin Accessibility yang sudah dimiliki Gulir.
/// Tanpa ⌥, event scroll diteruskan apa adanya ke app lain.
final class TrackpadSwipe {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var tracker: SwipeTracker
    private let isActive: () -> Bool
    private let onStep: (SwipeTracker.Step) -> Void

    /// Gestur yang dimulai dengan ⌥ ditelan seluruhnya (termasuk momentum-nya),
    /// walau ⌥ dilepas di tengah jalan, supaya app di bawah kursor tidak ikut scroll.
    private var swallowing = false

    init(threshold: CGFloat, isActive: @escaping () -> Bool, onStep: @escaping (SwipeTracker.Step) -> Void) {
        tracker = SwipeTracker(threshold: threshold)
        self.isActive = isActive
        self.onStep = onStep
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: trackpadSwipeCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            NSLog("Gulir: gagal memasang event tap untuk gestur trackpad")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard type == .scrollWheel,
              event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 else { return pass }

        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        let dx = CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2))
        let dy = CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))

        // Gestur baru: putuskan sekali di awal apakah gestur ini milik Gulir
        if phase == Self.phaseBegan || phase == Self.phaseMayBegin {
            swallowing = isOptionOnly(event.flags) && isActive()
        }
        guard swallowing else { return pass }

        if momentum != 0 {
            if momentum == Self.momentumEnd { swallowing = false }
            return nil // momentum tidak dihitung, tapi tetap ditelan
        }

        let trackerPhase: SwipeTracker.Phase
        switch phase {
        case Self.phaseBegan, Self.phaseMayBegin: trackerPhase = .began
        case Self.phaseEnded, Self.phaseCancelled: trackerPhase = .ended
        default: trackerPhase = .changed
        }
        let steps = tracker.feed(deltaX: dx, deltaY: dy, phase: trackerPhase)
        if !steps.isEmpty {
            // Jangan jalankan AX di dalam callback: event tap dimatikan sistem kalau lambat
            DispatchQueue.main.async { [onStep] in steps.forEach(onStep) }
        }
        return nil
    }

    private func isOptionOnly(_ flags: CGEventFlags) -> Bool {
        flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift]) == .maskAlternate
    }

    // Nilai CGScrollPhase / CGMomentumScrollPhase
    private static let phaseBegan: Int64 = 1
    private static let phaseEnded: Int64 = 4
    private static let phaseCancelled: Int64 = 8
    private static let phaseMayBegin: Int64 = 128
    private static let momentumEnd: Int64 = 3
}

private func trackpadSwipeCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                   refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<TrackpadSwipe>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
}
