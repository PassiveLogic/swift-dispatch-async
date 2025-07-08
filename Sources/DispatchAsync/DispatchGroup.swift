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

// MARK: - Public Interface for Non-Async Usage -

/// `DispatchGroup` is a drop-in replacement for the `DispatchGroup` implemented
/// in Grand Central Dispatch. However, this class uses Swift Concurrency, instead of low-level threading API's.
///
/// The primary goal of this implementation is to enable WASM support for Dispatch.
///
/// Refer to documentation for the original [DispatchGroup](https://developer.apple.com/documentation/dispatch/dispatchgroup)
/// for more details,
@available(macOS 10.15, *)
public class DispatchGroup: @unchecked Sendable {
    private let group = _AsyncGroup()
    private let queue = FIFOQueue()

    public func enter() {
        queue.enqueue { [weak self] in
            guard let self else { return }
            await group.enter()
        }
    }

    public func leave() {
        queue.enqueue { [weak self] in
            guard let self else { return }
            await group.leave()
        }
    }

    public func notify(queue notificationQueue: DispatchQueue, execute work: @escaping @Sendable @convention(block) () -> Void) {
        queue.enqueue { [weak self] in
            guard let self else { return }
            await group.notify {
                await withCheckedContinuation { continuation in
                    notificationQueue.async {
                        work()
                        continuation.resume()
                    }
                }
            }
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            queue.enqueue { [weak self] in
                guard let self else { return }
                // NOTE: We use a task for the wait, because
                // otherwise the queue won't execute any more
                // tasks until the wait finishes, which is not the
                // behavior we want here. We want to enqueue the wait
                // in FIFO call order, but then we want to allow the wait
                // to be non-blocking for the queue until the last leave
                // is called on the group.
                Task {
                    await group.wait()
                    continuation.resume()
                }
            }
        }
    }

    public init() {}
}

// MARK: - Private Interface for Async Usage -

@available(macOS 10.15, *)
fileprivate actor _AsyncGroup {
    private var taskCount = 0
    private var notifyHandlers: [@Sendable () async -> Void] = []

    func enter() {
        taskCount += 1
    }

    func leave() {
        defer {
            checkCompletion()
        }
        guard taskCount > 0 else {
            assertionFailure("leave() called more times than enter()")
            return
        }
        taskCount -= 1
    }

    func notify(handler: @escaping @Sendable () async -> Void) {
        notifyHandlers.append(handler)
        checkCompletion()
    }

    func wait() async {
        if taskCount <= 0 {
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            notify {
                continuation.resume()
            }
            checkCompletion()
        }
    }

    private func checkCompletion() {
        if taskCount <= 0, !notifyHandlers.isEmpty {
            let handlers = notifyHandlers
            notifyHandlers.removeAll()

            for handler in handlers {
                Task {
                    await handler()
                }
            }
        }
    }
}
