//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 PassiveLogic, Inc.
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// NOTE: The following typealias mirrors Dispatch API's, but only for
// specific compilation conditions where Dispatch is not available.
// It is designed to safely elide away if and when Dispatch is introduced
// in the required Dispatch support becomes available.
#if os(WASI) && !canImport(Dispatch)
/// Drop-in replacement for ``Dispatch.DispatchSemaphore``, implemented using pure swift.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public typealias DispatchSemaphore = DispatchAsync.DispatchSemaphore
#endif // os(WASI) && !canImport(Dispatch)

extension DispatchAsync {
    /// DispatchSemaphore is not safe to use for most wasm executables.
    ///
    /// This implementation assumes the single-threaded
    /// environment that swift wasm executables typically run in.
    ///
    /// It is not appropriate for true multi-threaded environments.
    ///
    /// For safety, this class is only defined for WASI platforms.
    ///
    /// Most wasm executables are single-threaded. Calling DispatchSemaphore.wait
    /// when it's value is 0 or lower would be likely cause a frozen main thread,
    /// because that would block the calling thread. And there is usually
    /// only one thread in the wasm world (right now).
    ///
    /// For now, we guard against that case with both compile-time deprecation
    /// pointing to the much safer ``AsyncSemaphore``, and also at run-time with
    /// assertions.
    ///
    /// ``AsyncSemaphore`` provides full functionality, but only exposes
    /// Swift Concurrency api's with a safe async wait function.
    #if !os(WASI)
    @_spi(DispatchAsyncSingleThreadedSemaphore)
    #endif
    @available(
        *,
         deprecated,
         renamed: "AsyncSemaphore",
         message: "DispatchSemaphore.wait is dangerous because of it's thread-blocking nature. Use AsyncSemaphore and Swift Concurrency instead."
    )
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public class DispatchSemaphore: @unchecked Sendable {
        public var value: Int

        public init(value: Int) {
            self.value = value
        }

        @discardableResult
        public func signal() -> Int {
            MainActor.assertIsolated()
            value += 1
            return value
        }

        public func wait() {
            // NOTE: wasm is currently mostly single threaded.
            // And we don't have a Thread.sleep API yet.
            // So assert that we're on the main actor here. Usage from other
            // actors is not currently supported.
            MainActor.assertIsolated()
            assert(value > 0, "DispatchSemaphore is currently only designed for single-threaded use.")
            value -= 1
        }
    }
}
