import Testing

@testable import DispatchAsync

@Test
func dispatchTimeIntervalEquality() throws {
    // 1 second == 1_000 milliseconds
    #expect(DispatchTimeInterval.seconds(1) == .milliseconds(1_000))

    // 1 second != 2 seconds
    #expect(DispatchTimeInterval.seconds(1) != .seconds(2))

    // 2_000 micro-seconds == 1 milliseconds
    #expect(DispatchTimeInterval.microseconds(2_000) == .milliseconds(2))

    // 1 micro-seconds == 1_000 nanoseconds
    #expect(DispatchTimeInterval.microseconds(1) == .nanoseconds(1_000))

    // `.never` is only equal to `.never`
    #expect(DispatchTimeInterval.never == .never)
    #expect(DispatchTimeInterval.never != .seconds(0))
    #expect(DispatchTimeInterval.never != .seconds(Int.max))
}
