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

@available(macOS 13, *)
public typealias DispatchTime = ContinuousClock.Instant

/// The very first time someone tries to reference a `uptimeNanoseconds` or a similar
/// function that references a beginning point, this variable will be initialized as a beginning
/// reference point. This guarantees that all calls to `uptimeNanoseconds` or similar
/// will be 0 or greater.
///
/// By design, it is not possible to related `ContinuousClock.Instant` to
/// `ProcessInfo.processInfo.systemUptime`, and even if one devised such
/// a mechanism, it would open the door for fingerprinting. It's best to let the concept
/// of uptime be relative to previous uptime calls.
@available(macOS 13, *)
private let uptimeBeginning: DispatchTime = DispatchTime.now()

@available(macOS 13, *)
extension DispatchTime {
    public static func now() -> DispatchTime {
        now
    }

    public var uptimeNanoseconds: UInt64 {
        let beginning = uptimeBeginning
        let rightNow = DispatchTime.now()
        let uptimeDuration: Int64 = beginning.duration(to: rightNow).nanosecondsClamped
        guard uptimeDuration >= 0 else {
            assertionFailure("It shouldn't be possible to get a negative duration since uptimeBeginning.")
            return 0
        }
        return UInt64(uptimeDuration)
    }
}

// NOTE: The following was copied from swift-nio/Source/NIOCore/TimeAmount+Duration on June 27, 2025
// It was copied rather than brought via dependencies to avoid introducing
// a dependency on swift-nio for such a small piece of code.
//
// This library will need to have no depedendencies to be able to be integrated into GCD.
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Swift.Duration {
    /// The duration represented as nanoseconds, clamped to maximum expressible value.
    fileprivate var nanosecondsClamped: Int64 {
        let components = self.components

        let secondsComponentNanos = components.seconds.multipliedReportingOverflow(by: 1_000_000_000)
        let attosCompononentNanos = components.attoseconds / 1_000_000_000
        let combinedNanos = secondsComponentNanos.partialValue.addingReportingOverflow(attosCompononentNanos)

        guard
            !secondsComponentNanos.overflow,
            !combinedNanos.overflow
        else {
            return .max
        }

        return combinedNanos.partialValue
    }
}
