import Testing

@testable import DispatchAsync

@Test(.timeLimit(.minutes(1)))
func asyncSemaphoreWaitSignal() async throws {
    let semaphore = AsyncSemaphore(value: 1)

    // First wait should succeed immediately and bring the count to 0
    await semaphore.wait()

    // Launch a task that tries to wait – it should be suspended until we signal
    nonisolated(unsafe) var didEnterCriticalSection = false
    await withCheckedContinuation { continuation in
        Task { @Sendable in
            // Ensure the rest of this test doesn't
            // proceed until the Task block has started executing
            continuation.resume()

            await semaphore.wait()
            didEnterCriticalSection = true
            await semaphore.signal()
        }
    }

    // Allow the task a few cycles to reach the initial semaphore.wait()
    try? await Task.sleep(nanoseconds: 1_000)

    #expect(!didEnterCriticalSection)  // should still be waiting

    // Now release the semaphore – the waiter should proceed
    await semaphore.signal()

    // Wait for second signal to fire from inside the task above
    // There is a timeout on this test, so if there is a problem
    // we'll either hit the timeout and fail, or didEnterCriticalSection
    // will be false below
    await semaphore.wait()

    #expect(didEnterCriticalSection)   // waiter must have run
}
