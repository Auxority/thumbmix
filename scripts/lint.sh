#!/usr/bin/env bash
# Style check with the toolchain's own formatter and the repo's .swift-format.
# Fix findings with: swift format format --in-place --recursive Core/Sources Core/Tests Core/Package.swift App UITests
set -euo pipefail
cd "$(dirname "$0")/.."

swift format lint --strict --recursive Core/Sources Core/Tests Core/Package.swift App UITests
echo "swift format: clean"
