#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2025 Apple Inc. and the Swift.org project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift.org project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# TODO: Remove this file once there is a valid reference available in github from
# this PR: https://github.com/apple/swift-nio/pull/3159

set -euo pipefail

version="$(swiftc --version | head -n1)"
tag="$(curl -sL "https://raw.githubusercontent.com/swiftwasm/swift-sdk-index/refs/heads/main/v1/tag-by-version.json" | jq -e -r --arg v "$version" '.[$v] | .[-1]')"
curl -sL "https://raw.githubusercontent.com/swiftwasm/swift-sdk-index/refs/heads/main/v1/builds/$tag.json" | jq -r '.["swift-sdks"]["wasm32-unknown-wasi"] | "swift sdk install \"\(.url)\" --checksum \"\(.checksum)\""' | sh -x
