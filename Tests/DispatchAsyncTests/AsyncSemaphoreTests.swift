import Testing

@testable import DispatchAsync

@Test
func asyncSemaphoreWaitSignal() async throws {
    let semaphore = AsyncSemaphore(value: 1)

    // First wait should succeed immediately and bring the count to 0
    await semaphore.wait()

    // Launch a task that tries to wait – it should be suspended until we signal
    var didEnterCriticalSection = false
    let waiter = Task {
        await semaphore.wait()
        didEnterCriticalSection = true
        await semaphore.signal()
    }

    // Allow the task a brief moment to start and (hopefully) suspend
    try? await Task.sleep(nanoseconds: 1_000)

    #expect(!didEnterCriticalSection)  // should still be waiting

    // Now release the semaphore – the waiter should proceed
    await semaphore.signal()

    // Give the waiter a chance to run
    try? await Task.sleep(nanoseconds: 1_000)

    #expect(didEnterCriticalSection)   // waiter must have run

    _ = await waiter.value
}
