import AppKit
import CoreGraphics

/// UM fork: lets the remote's mic button drive Wispr Flow (or anything
/// else bound to a held fn key). Measured on the 2017 Intel MacBook: the
/// remote's own mic only delivers ~1/3 of the audio over this Mac's BLE link
/// (one 20 ms Opus frame per ~61 ms), so transcription from it is choppy.
/// Holding fn hands dictation to Wispr, which records from the Mac/headset
/// mic instead.
@MainActor
final class FnKeyHold {
    private(set) var isHeld = false
    private var safetyRelease: DispatchWorkItem?
    /// A stuck fn would leave Wispr recording forever; release after this.
    private let maxHoldSeconds: TimeInterval = 90

    static var wisprInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.electron.wispr-flow") != nil
            || FileManager.default.fileExists(atPath: "/Applications/Wispr Flow.app")
    }

    func press() {
        guard !isHeld else { return }
        isHeld = true
        post(down: true)
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolatedCompat { self?.release() }
        }
        safetyRelease = work
        DispatchQueue.main.asyncAfter(deadline: .now() + maxHoldSeconds, execute: work)
    }

    func release() {
        safetyRelease?.cancel()
        safetyRelease = nil
        guard isHeld else { return }
        isHeld = false
        post(down: false)
    }

    private func post(down: Bool) {
        // keycode 63 = fn. A flagsChanged event carrying the SecondaryFn
        // mask is what a real fn press produces.
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 63, keyDown: down) else { return }
        event.type = .flagsChanged
        event.flags = down ? .maskSecondaryFn : []
        event.post(tap: .cghidEventTap)
    }
}
