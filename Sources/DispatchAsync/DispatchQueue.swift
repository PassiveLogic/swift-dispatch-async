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
/// Drop-in replacement for ``Dispatch.DispatchQueue``, implemented using pure swift.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public typealias DispatchQueue = DispatchAsync.DispatchQueue
#endif

extension DispatchAsync {
    /// Drop-in replacement for ``Dispatch.DispatchQueue``, implemented using pure swift.
    ///
    /// The primary goal of this implementation is to enable WASM support for Dispatch.
    ///
    /// Refer to documentation for the original [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
    /// for more details,
    #if !os(WASI)
    @_spi(DispatchAsync)
    #endif
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public class DispatchQueue: @unchecked Sendable {
        public static let main = DispatchQueue(isMain: true)

        private static let _global = DispatchQueue(attributes: .concurrent)
        public static func global() -> DispatchQueue {
            Self._global
        }

        public enum Attributes {
            case concurrent

            fileprivate var isConcurrent: Bool {
                switch self {
                case .concurrent:
                    return true
                }
            }
        }

        private let targetQueue: DispatchQueue?

        private let serialQueue = FIFOQueue()

        /// Indicates whether calling context is running from the main DispatchQueue instance, or some other DispatchQueue instance.
        @TaskLocal public static var isMain = false

        /// This is set during the initialization of the DispatchQueue, and controls whether `async` calls run on MainActor or not
        private let isMain: Bool
        private let label: String?
        private let attributes: DispatchQueue.Attributes?

        public convenience init(
            label: String? = nil,
            attributes: DispatchQueue.Attributes? = nil,
            target: DispatchQueue? = nil
        ) {
            self.init(isMain: false, label: label, attributes: attributes, target: target)
        }

        private init(
            isMain: Bool,
            label: String? = nil,
            attributes: DispatchQueue.Attributes? = nil,
            target: DispatchQueue? = nil
        ) {
            if isMain, attributes == .concurrent {
                assertionFailure("Should never create a concurrent main queue. Main queue should always be serial.")
            }

            self.isMain = isMain
            self.label = label
            self.attributes = attributes
            self.targetQueue = target
        }

        public func async(
            execute work: @escaping @Sendable @convention(block) () -> Void
        ) {
            if let targetQueue, targetQueue !== self {
                // Recursively call this function on the target queue
                // until we reach a nil queue, or this queue.
                targetQueue.async(execute: work)
            } else {
                if isMain {
                    Task { @MainActor [work] in
                        DispatchQueue.$isMain.withValue(true) { @MainActor [work] in
                            work()
                        }
                    }
                } else {
                    if attributes?.isConcurrent == true {
                        Task { // FIFO is not important for concurrent queues, using global task executor here
                            work()
                        }
                    } else {
                        // We don't need to use a task for enqueing work to a non-main serial queue
                        // because the enqueue process is very light-weight, and it is important to
                        // preserve FIFO entry into the queue as much as possible.
                        serialQueue.enqueue(work)
                    }
                }
            }
        }
    }

    /// A tiny FIFO job runner that executes each submitted async closure
    /// strictly in the order it was enqueued.
    #if !os(WASI)
    @_spi(DispatchAsync)
    #endif
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public actor FIFOQueue {
        /// A single item in the stream, which is a block of work that can be completed.
        public typealias WorkItem = @Sendable () async -> Void

        /// The stream’s continuation; lives inside the actor so nobody
        /// else can yield into it.
        private let continuation: AsyncStream<WorkItem>.Continuation

        /// Spin up the stream and the single draining task.
        public init(bufferingPolicy: AsyncStream<WorkItem>.Continuation.BufferingPolicy = .unbounded) {
            let stream: AsyncStream<WorkItem>
            (stream, self.continuation) = AsyncStream.makeStream(of: WorkItem.self, bufferingPolicy: bufferingPolicy)

            // Dedicated worker that processes work items one-by-one.
            Task {
                for await work in stream {
                    // Run each job in order, allowing suspension, and awaiting full
                    // completion, before running the next work item
                    await work()
                }
            }
        }

        /// Enqueue a new unit of work.
        @discardableResult
        nonisolated func enqueue(_ workItem: @escaping WorkItem) -> AsyncStream<WorkItem>.Continuation.YieldResult {
            // Never suspends, preserves order
            continuation.yield(workItem)
        }

        deinit {
            // Clean shutdown on deinit
            continuation.finish()
        }
    }
}
