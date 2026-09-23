import Foundation

/// `MainActor.assumeIsolated` is macOS 14+. The UM fork targets macOS 13
/// (the newest a 2017 Intel MacBook Pro runs), so this backports it: on 14+
/// it defers to the real API; on 13 it asserts we are on the main thread
/// and runs the closure there. Every call site in this app is already on
/// the main thread (RunLoop.main.perform / main-queue callbacks).
extension MainActor {
    static func assumeIsolatedCompat<T: Sendable>(
        _ operation: @MainActor () throws -> T
    ) rethrows -> T {
        if #available(macOS 14.0, *) {
            return try MainActor.assumeIsolated(operation)
        }
        dispatchPrecondition(condition: .onQueue(.main))
        return try withoutActuallyEscaping(operation) { fn in
            try unsafeBitCast(fn, to: (() throws -> T).self)()
        }
    }
}
