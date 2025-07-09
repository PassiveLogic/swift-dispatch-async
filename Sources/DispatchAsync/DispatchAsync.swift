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

/// Top level namespace for functionality provided in DispatchAsync.
///
/// Used to avoid namespacing conflicts with `Dispatch` and `Foundation`
///
/// Platforms other than WASI shouldn't consume this library for now
/// except for testing and development purposes.
///
/// TODO: SM: Add github permalink to this, after it is merged.
#if !os(WASI)
@_spi(DispatchAsync)
#endif
public enum DispatchAsync {}
