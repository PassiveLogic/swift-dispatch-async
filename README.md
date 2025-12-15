# swift-dispatch-async

DispatchAsync provides a pure-swift implementation of `Dispatch`, powered by Swift Concurrency. It is currently intended for use only
in WASM targets, but could be used in other scenarios should the need arise. 

The Swift for WebAssembly SDK [doesn't currenty include Dispatch](https://book.swiftwasm.org/getting-started/porting.html#swift-foundation-and-dispatch). 
But, it does support Swift Concurrency. DispatchAsync implements a number of common Dispatch API's using Swift Concurrency
under the hood. This allows `import DispatchAsync` to be used in wasm targets as a drop-in replacement anywhere `import Dispatch` is
currently in use.

Dispatch Async does not provide blocking API's such as `DispatchQueue.sync`, primarily due to the intentional lack of blocking
API's in Swift Concurrency.

# Usage

PassiveLogic plans to mainstream this into the SwiftWasm toolchain. If possible, it's better to wait until this is part of the
official Swift for WebAssembly SDK. But if you need this now, below are some usage tips.

## 1. Only use this for WASI platforms, and only if Dispatch cannot be imported.

Use `#if os(WASI) && !canImport(Dispatch)` to elide usages outside of WASI platforms:

```swift
#if os(WASI) && !canImport(Dispatch)
import DispatchAsync
#else
import Dispatch
#endif

// Use Dispatch API's the same way you normal would.
```

## 2. If you really want to use DispatchAsync as a pure Swift Dispatch alternative for non-wasm targets

Stop. Are you sure? If you do this, you'll need to be careful with all `import Dispatch`, `import Foundation`, and many other issues.

1. Add the dependency to your package:

```swift
let package = Package(
    name: "MyPackage",
    products: [
        .library(
            name: "MyPackage",
            targets: [
                "MyPackage"
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/PassiveLogic/swift-dispatch-async.git",
            from: "0.0.1"
        ),
    ],
    targets: [
        .target(
            name: "MyPackage"
            dependencies: [
                .product(name: "DispatchAsync", package: "swift-dispatch-async", condition: .when(platforms: [.wasi])),
            ]
        ),
    ]
)
```

2. Import and use DispatchAsync in place of Dispatch like this:

```swift
#if os(WASI) && !canImport(Dispatch)
import DispatchAsync
#else
// Non-WASI platforms have to explicitly bring in DispatchAsync
// by using `@_spi`.
@_spi(DispatchAsync) import DispatchAsync
#endif

// Not allowed, brings in Dispatch, aka "the real GCD":
// import Dispatch

// Also not allowed, brings in Dispatch
// import Foundation

// You'll need to use scoped Foundation imports:
import struct Foundation.URL // Ok. Doesn't bring in Dispatch

// If you ignore the above notes, but do the following, be prepared for namespace
// collisions between the toolchain's Dispatch and DispatchAsync:

private typealias DispatchQueue = DispatchAsync.DispatchQueue // Ok as long as Dispatch isn't imported

// Ok. If you followed everything above, you can now do the following, using pure Swift
// under the hood! 🎉
DispatchQueue.main.async {
    // Run your code here…
}
```

# Toolchain Adoption Plans

DispatchAsync is not meant for consumption abroad directly as a new Swift Module. Rather, the intention is to provide eventual integration
as a drop-in replacement for Dispatch when compiling to Wasm.

There are a few paths to adoption into the Swift toolchain

- DispatchAsync can be emplaced inside the [libDispatch repository](https://github.com/swiftlang/swift-corelibs-libdispatch), and compiled
into the toolchain only for wasm targets.
- DispatchAsync can be consumed in place of libDispatch when building the Swift toolchain.

Ideally, with either approach, this repository would transfer ownership to the swiftlang organization.

In the interim, to move wasm support forward, portions of DispatchAsync may be inlined (copy-pasted)
into various libraries to enable wasm support. DispatchAsync is designed for this purpose, and has
special `#if` handling to ensure that existing temporary usages will be elided without breakage
the moment SwiftWasm adds support for `Dispatch` into the toolchain.

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

# LICENSE

This project is distributed by PassiveLogic under the Apache-2.0 license. See
[LICENSE](https://github.com/PassiveLogic/swift-dispatch-async/blob/main/LICENSE) for full terms of use.

