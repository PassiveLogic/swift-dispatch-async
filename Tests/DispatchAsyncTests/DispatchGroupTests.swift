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

import func Foundation.sin

#if !os(WASI)
import class Foundation.Thread
#endif

private typealias DispatchGroup = DispatchAsync.DispatchGroup
private typealias DispatchQueue = DispatchAsync.DispatchQueue

@Suite("DispatchGroup Tests")
struct DispatchGroupTests {
    @Test(arguments: [1000])
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func dispatchGroupOrderCleanliness(repetitions: Int) async throws {
        // Repeating this `repetitions` number of times to help rule out
        // edge cases that only show up some of the time
        for index in 0 ..< repetitions {
            Task {
                actor Result {
                    private(set) var value = ""

                    func append(value: String) {
                        self.value.append(value)
                    }
                }

                let result = Result()

                let group = DispatchGroup()
                await result.append(value: "|🔵\(index)")

                group.enter()
                Task {
                    await result.append(value: "🟣/")
                    group.leave()
                }

                group.enter()
                Task {
                    await result.append(value: "🟣^")
                    group.leave()
                }

                group.enter()
                Task {
                    await result.append(value: "🟣\\")
                    group.leave()
                }

                await withCheckedContinuation { continuation in
                    group.notify(queue: .main) {
                        Task {
                            await result.append(value: "🟢\(index)=")
                            continuation.resume()
                        }
                    }
                }

                let finalValue = await result.value

                /// NOTE: If you need to visually debug issues, you can uncomment
                /// the following to watch a visual representation of the group ordering.
                ///
                /// In general, you'll see something like the following printed over and over
                /// to the console:
                ///
                /// ```
                /// |🔵42🟣/🟣^🟣\🟢42=
                /// ```
                ///
                /// What you should observe:
                ///
                /// - The index number be the same at the beginning and end of each line, and it
                /// should always increment by one.
                /// - The 🔵 should always be first, and the 🟢 should always be last for each line.
                /// - There should always be 3 🟣's in between the 🔵 and 🟢.
                /// - The ordering of the 🟣 can be random, and that is fine.
                ///
                /// For example, for of the following are valid outputs:
                ///
                /// ```
                /// // GOOD
                /// |🔵42🟣/🟣^🟣\🟢42=
                /// ```
                ///
                /// ```
                /// // GOOD
                /// |🔵42🟣/🟣\🟣^🟢42=
                /// ```
                ///
                /// But the following would not be valid:
                ///
                /// ```
                /// // BAD! (43 comes before 42)
                /// |🔵43🟣/🟣^🟣\🟢43=
                /// |🔵42🟣/🟣^🟣\🟢42=
                /// |🔵44🟣/🟣^🟣\🟢44=
                /// ```
                ///
                /// ```
                /// // BAD! (green globe comes before a purple one)
                /// |🔵42🟣/🟣^🟢42🟣\=
                /// ```
                ///

                // NOTE: Uncomment to use troubleshooting method above:
                // print(finalValue)

                #expect(finalValue.prefix(1) == "|")
                #expect(finalValue.count { $0 == "🟣" } == 3)
                #expect(finalValue.count { $0 == "🟢" } == 1)
                #expect(finalValue.lastIndex(of: "🟣")! < finalValue.firstIndex(of: "🟢")!)
                #expect(finalValue.suffix(1) == "=")
            }
        }
    }

    /// Swift port of libdispatch/tests/dispatch_group.c
    ///
    /// See https://github.com/swiftlang/swift-corelibs-libdispatch/blob/686475721aca13d98d2eab3a0c439403d33b6e2d/tests/dispatch_group.c
    ///
    /// The original C test stresses `dispatch_group_wait` by enqueuing a bunch of
    /// math-heavy blocks on a global queue, then waiting for them to finish with a
    /// timeout.  It also verifies that `notify` is invoked exactly once.
    @Test(.timeLimit(.minutes(1)))
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func dispatchGroupStress() async throws {
        let iterations = 1000
        // We use a separate concurrent queue rather than the global queue to avoid interference issues
        // with other tests running in parallel
        let workQueue = DispatchQueue(attributes: .concurrent)
        let group = DispatchGroup()

        let isolationQueue = DispatchQueue(label: "isolationQueue")
        nonisolated(unsafe) var counter = 0

        for _ in 0 ..< iterations {
            group.enter()
            workQueue.async {
                // We alternate between two options for workload. One is a simple
                // math function, the other is a thread sleep.
                //
                // Alternating between those two approaches provides variance to
                // increases failure chances if there are race conditions subject to timing
                // and load.
                if Bool.random() {
                    #if !os(WASI)
                    Thread.sleep(forTimeInterval: 0.00001) // 10_000 nanoseconds
                    #endif
                } else {
                    // A small math workload similar to the original C test which used
                    // sin(random()). We iterate a couple thousand times to keep the CPU
                    // busy long enough for the group scheduling to matter.
                    var x = Double.random(in: 0.0 ... Double.pi)
                    for _ in 0 ..< 2_000 {
                        x = sin(x)
                    }
                }

                isolationQueue.async {
                    counter += 1
                    group.leave()
                }
            }
        }

        // NOTE: The test has a 1 minute time limit that will time out. In
        // the original code, this timeout was 5 seconds, but currently
        // the shortest timeout Swift Testing provides is 1 minute.
        await group.wait()

        // Verify notify fires exactly once.
        nonisolated(unsafe) var notifyHits = 0
        await withCheckedContinuation { k in
            group.notify(queue: .main) {
                notifyHits += 1
                k.resume()
            }
        }
        #expect(notifyHits == 1)

        let finalCount = counter
        #expect(finalCount == iterations)
    }
}
