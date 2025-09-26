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
/// Drop-in replacement for ``Dispatch.DispatchTime``, implemented using pure Swift.
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public typealias DispatchTime = DispatchAsync.DispatchTime
#endif

extension DispatchAsync {
    /// Drop-in replacement for ``Dispatch.DispatchTime``, implemented using pure Swift.
    #if !os(WASI)
    @_spi(DispatchAsync)
    #endif
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct DispatchTime {
        private let instant: ContinuousClock.Instant

        /// The very first time someone intializes a DispatchTime instance, we
        /// reference this static let, causing it to be initialized.
        ///
        /// This is the closest we can get to snapshotting the start time of the running
        /// executable, without using OS-specific calls. We want
        /// to avoid OS-specific calls to maximize portability.
        ///
        /// To keep this robust, we initialize `self.durationSinceBeginning`
        /// to this value using a default value, which is guaranteed to run before any
        /// initializers run. This guarantees that uptimeBeginning will be the very
        /// first
        @available(macOS 13, *)
        private static let uptimeBeginning: ContinuousClock.Instant = ContinuousClock.Instant.now

        /// See documentation for ``uptimeBeginning``. We intentionally
        /// use this to guarantee a capture of `now` to `uptimeBeginning` BEFORE
        /// any DispatchTime instances are initialized.
        private let durationSinceUptime = uptimeBeginning.duration(to: ContinuousClock.Instant.now)

        public init() {
            self.instant = ContinuousClock.Instant.now
        }

        public static func now() -> Self {
            DispatchTime()
        }

        public var uptimeNanoseconds: UInt64 {
            let beginning = DispatchTime.uptimeBeginning
            let uptimeDuration: Int64 = beginning.duration(to: self.instant).nanosecondsClamped
            guard uptimeDuration >= 0 else {
                assertionFailure("It shouldn't be possible to get a negative duration since uptimeBeginning.")
                return 0
            }
            return UInt64(uptimeDuration)
        }
    }
}

// NOTE: The following was copied from swift-nio/Source/NIOCore/TimeAmount+Duration on June 27, 2025.
//
// See https://github.com/apple/swift-nio/blob/83bc5b58440373a7678b56fa0d9cc22ca55297ee/Sources/NIOCore/TimeAmount%2BDuration.swift
//
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
