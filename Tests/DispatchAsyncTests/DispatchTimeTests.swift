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

@_spi(DispatchAsync) import DispatchAsync
import Testing

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private typealias DispatchTime = DispatchAsync.DispatchTime

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
@Test
func testDispatchTimeContinousClockBasics() async throws {
    let a = DispatchTime.now().uptimeNanoseconds
    let b = DispatchTime.now().uptimeNanoseconds
    try await Task.sleep(for: .nanoseconds(1))
    let c = DispatchTime.now().uptimeNanoseconds
    #expect(a < b)
    #expect(b < c)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
@Test
func testUptimeNanosecondsEqualityForConsecutiveCalls() async throws {
    let original = DispatchTime.now()
    let a = original.uptimeNanoseconds
    try await Task.sleep(for: .nanoseconds(100))
    let b = original.uptimeNanoseconds
    #expect(a == b)
}
