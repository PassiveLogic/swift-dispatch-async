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

import Testing

@_spi(DispatchAsync) import DispatchAsync

private typealias DispatchGroup = DispatchAsync.DispatchGroup

@Test
func dispatchGroupOrderCleanliness() async throws {
    // Repeating this 100 times to help rule out
    // edge cases that only show up some of the time
    for index in 0 ..< 100 {
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
            /// // BAD!
            /// |🔵43🟣/🟣^🟣\🟢43=
            /// |🔵42🟣/🟣^🟣\🟢42=
            /// |🔵44🟣/🟣^🟣\🟢44=
            /// ```
            ///
            /// ```
            /// // BAD!
            /// |🔵42🟣/🟣^🟢42🟣\=
            /// ```
            ///

            // Uncomment to use troubleshooting method above:
            // print(finalValue)

            #expect(finalValue.prefix(1) == "|")
            #expect(finalValue.count { $0 == "🟣" } == 3)
            #expect(finalValue.count { $0 == "🟢" } == 1)
            #expect(finalValue.lastIndex(of: "🟣")! < finalValue.firstIndex(of: "🟢")!)
            #expect(finalValue.suffix(1) == "=")
        }
    }
}
