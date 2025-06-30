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

import Testing

@testable import DispatchAsync

#if !os(WASI)
import class Foundation.Thread
#endif

@Test
func testBasicDispatchQueueMain() async throws {
    let asyncValue = await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
            // Main queue should be on main thread on apple platforms.
            // On linux platforms, there is no guarantee that the main queue is on the main thread,
            // only that it is on the main actor.

            #if os(Linux)
            #expect(DispatchQueue.isMain)
            #elseif !os(WASI)
            // NOTE: Thread API's aren't currently available on OS(WASI), as of June 2025
            #expect(Thread.isMainThread)
            #endif
            continuation.resume(returning: true)
        }
    }
    #expect(asyncValue == true)
}

@Test
func testBasicDispatchQueueGlobal() async throws {
    let asyncValue = await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            // Global queue should NOT be on main thread.
            #if !os(WASI)
            #expect(!Thread.isMainThread)
            #endif
            continuation.resume(returning: true)
        }
    }
    #expect(asyncValue == true)
}
