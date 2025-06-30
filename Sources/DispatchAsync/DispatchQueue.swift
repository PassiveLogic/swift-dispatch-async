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

/// `DispatchQueue` is a drop-in replacement for the `DispatchQueue` implemented
/// in Grand Central Dispatch. However, this class uses Swift Concurrency, instead of low-level threading API's.
///
/// The primary goal of this implementation is to enable WASM support for Dispatch.
///
/// Refer to documentation for the original [DispatchQueue](https://developer.apple.com/documentation/dispatch/dispatchqueue)
/// for more details,
@available(macOS 10.15, *)
public class DispatchQueue: @unchecked Sendable {
    public static let main = DispatchQueue(isMain: true)

    private static let _global = DispatchQueue()
    public static func global() -> DispatchQueue {
        Self._global
    }

    public enum Attributes {
        case concurrent
    }

    private let targetQueue: DispatchQueue?

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
                Task {
                    work()
                }
            }
        }
    }
}
