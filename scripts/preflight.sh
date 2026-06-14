#!/usr/bin/env bash
#
# Local commit gate that mirrors the CI `build-test` job: lint + format, then
# generate the project, build, and run the full test suite. Wired as a
# pre-commit hook (see .pre-commit-config.yaml) so a commit cannot land unless
# it would pass CI. Run it directly any time with `scripts/preflight.sh`.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "==> Lint + format (scripts/lint.sh)"
./scripts/lint.sh

echo "==> Generate Xcode project (xcodegen)"
xcodegen generate

echo "==> Build (Debug, macOS)"
xcodebuild -scheme Mural -configuration Debug -destination 'platform=macOS' build | xcbeautify

echo "==> Test (full suite)"
xcodebuild test -scheme Mural -destination 'platform=macOS' | xcbeautify

echo "==> Preflight passed"
