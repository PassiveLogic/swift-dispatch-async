# dispatch-async

## ⚠️ WARNING - This is an 🧪experimental🧪 repository and should not be adopted at large.

DispatchAsync is a temporary experimental repository aimed at implementing missing Dispatch support in the SwiftWasm toolchain.
Currently, [SwiftWasm doesn't include Dispatch](https://book.swiftwasm.org/getting-started/porting.html#swift-foundation-and-dispatch). 
But, SwiftWasm does support Swift Concurrency. DispatchAsync implements a number of common Dispatch API's using Swift Concurrency
under the hood.

Dispatch Async does not provide blocking API's such as `DispatchQueue.sync`, primarily due to the intentional lack of blocking
API's in Swift Concurrency.

# Toolchain Adoption Plans

DispatchAsync is not meant for consumption abroad directly as a new Swift Module. Rather, the intention is to provide eventual integration
as a drop-in replacement for Dispatch when compiling to Wasm.

There are a few paths to adoption into the Swift toolchain

- DispatchAsync can be emplaced inside the [libDispatch repository](https://github.com/swiftlang/swift-corelibs-libdispatch), and compiled
into the toolchain only for wasm targets.
- DispatchAsync can be consumed in place of libDispatch when building the Swift toolchain.

Ideally, with either approach, this repository would transfer ownership to the swiftlang organization.

# DispatchSemaphore Limitations

The current implementation of `DispatchSemaphore` has some limitations. Blocking threads goes against the design goals of Swift Concurrency.
The `wait` function on `DispatchSemaphore` goes against this goal. Furthermore, most wasm targets run on a single thread from the web
browser, so any time the `wait` function ends up blocking the calling thread, it would almost certainly freeze the single-threaded wasm
executable.

To navigate these issues, there are some limitations:

- For wasm compilation targets, `DispatchSemaphore` assumes single-threaded execution, and lacks various safeguards that would otherwise
be needed for multi-threaded execution. This makes the implementation much easier.
- For wasm targets, calls to `signal` and `wait` must be balanced. An assertion triggers if `wait` is called more times than `signal`.
- DispatchSemaphore is deprecated for wasm targets, and AsyncSemaphore is encouraged as the replacement.
- For non-wasm targets, DispatchSemaphore is simply a typealias for `AsyncSemaphore`, and provides only a non-blocking async `wait` 
function. This reduces potential issues that can arise from wait being a thread-blocking function. 
