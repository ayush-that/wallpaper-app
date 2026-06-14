#!/usr/bin/env bash
set -euo pipefail
swiftformat App Sources Tests Tools --lint
swiftlint lint --strict --quiet
