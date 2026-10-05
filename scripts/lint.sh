#!/usr/bin/env bash
# Style (swift-format, .swift-format) and simplicity (SwiftLint, .swiftlint.yml) checks.
# Fix style with: swift format format --in-place --recursive Core/Sources Core/Tests Core/Package.swift App UITests
set -euo pipefail
cd "$(dirname "$0")/.."

swift format lint --strict --recursive Core/Sources Core/Tests Core/Package.swift App UITests
echo "swift format: clean"

command -v swiftlint > /dev/null || { echo "swiftlint is missing: brew install swiftlint" >&2; exit 1; }
swiftlint lint --strict --quiet
echo "swiftlint: complexity and size within limits"
