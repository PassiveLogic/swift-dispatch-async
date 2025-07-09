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

import Testing

@testable import DispatchAsync

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
@Test(.timeLimit(.minutes(1)))
func asyncSemaphoreWaitSignal() async throws {
    let semaphore = AsyncSemaphore(value: 1)

    // First wait should succeed immediately and bring the count to 0
    await semaphore.wait()

    // Launch a task that tries to wait – it should be suspended until we signal
    nonisolated(unsafe) var didEnterCriticalSection = false
    await withCheckedContinuation { continuation in
        Task { @Sendable in
            // Ensure the rest of this test doesn't
            // proceed until the Task block has started executing
            continuation.resume()

            await semaphore.wait()
            didEnterCriticalSection = true
            await semaphore.signal()
        }
    }

    // Allow the task a few cycles to reach the initial semaphore.wait()
    try? await Task.sleep(nanoseconds: 1_000)

    #expect(!didEnterCriticalSection) // should still be waiting

    // Now release the semaphore – the waiter should proceed
    await semaphore.signal()

    // Wait for second signal to fire from inside the task above
    // There is a timeout on this test, so if there is a problem
    // we'll either hit the timeout and fail, or didEnterCriticalSection
    // will be false below
    await semaphore.wait()

    #expect(didEnterCriticalSection) // waiter must have run
}

@Test func basicAsyncSemaphoreTest() async throws {
    nonisolated(unsafe) var sharedPoolCompletionCount = 0
    sharedPoolCompletionCount = 0 // Reset to 0 for each test run
    let totalConcurrentPools = 10

    let semaphore = AsyncSemaphore(value: 1)

    await withTaskGroup(of: Void.self) { group in
        for _ in 0 ..< totalConcurrentPools {
            group.addTask {
                // Wait for any other pools currently holding the semaphore
                await semaphore.wait()

                // Only one task should mutate counter at a time
                //
                // If there are issues with the semaphore, then
                // we would expect to grab incorrect values here occasionally,
                // which would result in an incorrect final completion count.
                //
                let existingPoolCompletionCount = sharedPoolCompletionCount

                // Add artificial delay to amplify race conditions
                // Pools started shortly after this "semaphore-locked"
                // pool starts will run before this line, unless
                // this pool contains a valid lock.
                try? await Task.sleep(nanoseconds: 100)

                sharedPoolCompletionCount = existingPoolCompletionCount + 1

                // When we exit this flow, release our hold on the semaphore
                await semaphore.signal()
            }
        }
    }

    // After all tasks are done, counter should be 10
    #expect(sharedPoolCompletionCount == totalConcurrentPools)
}
