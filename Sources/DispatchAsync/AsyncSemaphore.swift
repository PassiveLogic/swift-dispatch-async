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

/// Provides a semaphore implantation in `async` context, with a safe wait method. Provides easy safer replacement
/// for DispatchSemaphore usage.
@available(macOS 10.15, *)
actor AsyncSemaphore {
    private var value: Int
    private var waiters: Array<CheckedContinuation<Void, Never>> = []

    init(value: Int = 1) {
        self.value = value
    }

    func wait() async {
        value -= 1
        if value >= 0 { return }
        await withCheckedContinuation {
            waiters.append($0)
        }
    }

    func signal() {
        self.value += 1

        guard !waiters.isEmpty else { return }
        let first = waiters.removeFirst()
        first.resume()
    }
}

@available(macOS 10.15, *)
extension AsyncSemaphore {
    func withLock<T: Sendable>(_ closure: () async throws -> T) async rethrows -> T {
        await wait()
        defer { signal() }
        return try await closure()
    }

    func withLockVoid(_ closure: () async throws -> Void) async rethrows {
        await wait()
        defer { signal() }
        try await closure()
    }
}
