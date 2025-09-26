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

// TODO: SM: Rename this file to AsyncSemaphoreTests (coming in next PR that adds tests)

import Testing

@testable import DispatchAsync

// NOTE: AsyncSempahore is nearly API-compatible with DispatchSemaphore,
// This typealias helps demonstrate that fact.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
private typealias DispatchSemaphore = AsyncSemaphore

nonisolated(unsafe) private var sharedPoolCompletionCount = 0

@Test func basicAsyncSemaphoreTest() async throws {
    let totalConcurrentPools = 10

    let semaphore = DispatchSemaphore(value: 1)

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
