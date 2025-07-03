import Testing

@testable import DispatchAsync

/// Ping-Pong queue test  is adapted from the test
/// [dispatch_pingpong.c in libdispatch](https://github.com/swiftlang/swift-corelibs-libdispatch/blob/main/tests/dispatch_pingpong.c).
///
/// Two queues recursively schedule work on each other N times. The test
/// succeeds when the hand-off count matches expectations and no deadlock
/// occurs.
@Test
func dispatchPingPongQueues() async throws {
    // NOTE: Original test uses 10_000_000, but that makes for a rather slow
    // unit test. Using 100_000 here as a "close-enough" tradeoff.
    let totalIterations = 100_000 // Total number of hand-offs between ping and pong functions.

    let queuePing = DispatchQueue(label: "ping")
    let queuePong = DispatchQueue(label: "pong")

    // NOTE: We intentionally use a nonisolated
    // variable here rather than an actor-protected or
    // semaphore-protected variable to force reliance on
    // the separate and serial queues waiting to execute
    // until another value is enqueued.
    //
    // This matches the implementation of the dispatch_pinpong.c test.
    nonisolated(unsafe) var counter = 0

    // Ping
    @Sendable
    func schedulePing(_ iteration: Int, _ continuation: CheckedContinuation<Void, Never>) {
        queuePing.async {
            counter += 1
            if iteration < totalIterations {
                schedulePong(iteration + 1, continuation)
            } else {
                continuation.resume()
            }
        }
    }

    // Pong
    @Sendable
    func schedulePong(_ iteration: Int, _ continuation: CheckedContinuation<Void, Never>) {
        queuePong.async {
            counter += 1
            schedulePing(iteration, continuation)
        }
    }

    await withCheckedContinuation { continuation in
        // Start the chain. Chain will resume continuation when totalIterations
        // have been reached.
        schedulePing(0, continuation)
    }

    let finalCount = counter
    // Each iteration performs two increments (ping + pong)
    #expect(finalCount == totalIterations * 2 + 1) // + 1 is for the final ping increment on the final iteration where i==totalIterations
}
