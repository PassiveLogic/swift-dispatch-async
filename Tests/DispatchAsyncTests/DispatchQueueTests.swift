//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
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
            // Main queue should be on main thread.
            #if !os(WASI)
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
