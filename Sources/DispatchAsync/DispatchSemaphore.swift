//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// This implementation assumes the single-threaded
// environment that swift wasm executables typically run in.
//
// It is not appropriate for true multi-threaded environments.
//
// For safety, this class is only defined for WASI platforms.
//
//
#if os(WASI)

/// DispatchSemaphore is not safe to use for most wasm executables.
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
@available(
    *,
    deprecated,
    renamed: "AsyncSemaphore",
    message: "DispatchSemaphore.wait is dangerous because of it's thread-blocking nature. Use AsyncSemaphore and Swift Concurrency instead."
)
@available(macOS 10.15, *)
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
        // So
        MainActor.assertIsolated()
        assert(value > 0, "DispatchSemaphore is currently only designed for single-threaded use.")
        value -= 1
    }
}

#else

@available(macOS 10.15, *)
typealias DispatchSemaphore = AsyncSemaphore

#endif // #if os(WASI)
