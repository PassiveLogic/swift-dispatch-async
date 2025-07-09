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

@_spi(DispatchAsync) import DispatchAsync

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private typealias DispatchTime = DispatchAsync.DispatchTime

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
@Test
func testDispatchTimeContinousClockBasics() async throws {
    let a = DispatchTime.now().uptimeNanoseconds
    let b = DispatchTime.now().uptimeNanoseconds
    #expect(a <= b)
}
