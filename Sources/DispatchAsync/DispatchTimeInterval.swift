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

// NOTE: The following typealias mirrors Dispatch API's, but only for
// specific compilation conditions where Dispatch is not available.
// It is designed to safely elide away if and when Dispatch is introduced
// in the required Dispatch support becomes available.
#if os(WASI) && !canImport(Dispatch)
/// Drop-in replacement for ``Dispatch.DispatchQueue``, implemented using pure swift.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public typealias DispatchTimeInterval = DispatchAsync.DispatchTimeInterval
#endif

extension DispatchAsync {
    private static let kNanosecondsPerSecond: UInt64 = 1_000_000_000
    private static let kNanosecondsPerMillisecond: UInt64 = 1_000_000
    private static let kNanoSecondsPerMicrosecond: UInt64 = 1_000

    /// NOTE: This is an excerpt from libDispatch, see
    /// https://github.com/swiftlang/swift-corelibs-libdispatch/blob/main/src/swift/Time.swift#L168
    ///
    /// Represents a time interval that can be used as an offset from a `DispatchTime`
    /// or `DispatchWallTime`.
    ///
    /// For example:
    ///     let inOneSecond = DispatchTime.now() + DispatchTimeInterval.seconds(1)
    ///
    /// If the requested time interval is larger then the internal representation
    /// permits, the result of adding it to a `DispatchTime` or `DispatchWallTime`
    /// is `DispatchTime.distantFuture` and `DispatchWallTime.distantFuture`
    /// respectively. Such time intervals compare as equal:
    ///
    ///     let t1 = DispatchTimeInterval.seconds(Int.max)
    ///        let t2 = DispatchTimeInterval.milliseconds(Int.max)
    ///        let result = t1 == t2   // true
    #if !os(WASI)
    @_spi(DispatchAsync)
    #endif
    public enum DispatchTimeInterval: Equatable, Sendable {
        case seconds(Int)
        case milliseconds(Int)
        case microseconds(Int)
        case nanoseconds(Int)
        case never

        internal var rawValue: Int64 {
            switch self {
            case .seconds(let s): return clampedInt64Product(Int64(s), Int64(kNanosecondsPerSecond))
            case .milliseconds(let ms): return clampedInt64Product(Int64(ms), Int64(kNanosecondsPerMillisecond))
            case .microseconds(let us): return clampedInt64Product(Int64(us), Int64(kNanoSecondsPerMicrosecond))
            case .nanoseconds(let ns): return Int64(ns)
            case .never: return Int64.max
            }
        }

        public static func == (lhs: DispatchTimeInterval, rhs: DispatchTimeInterval) -> Bool {
            switch (lhs, rhs) {
            case (.never, .never): return true
            case (.never, _): return false
            case (_, .never): return false
            default: return lhs.rawValue == rhs.rawValue
            }
        }

        // Returns m1 * m2, clamped to the range [Int64.min, Int64.max].
        // Because of the way this function is used, we can always assume
        // that m2 > 0.
        private func clampedInt64Product(_ m1: Int64, _ m2: Int64) -> Int64 {
            assert(m2 > 0, "multiplier must be positive")
            let (result, overflow) = m1.multipliedReportingOverflow(by: m2)
            if overflow {
                return m1 > 0 ? Int64.max : Int64.min
            }
            return result
        }
    }
}
