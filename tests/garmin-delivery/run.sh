#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
build="$(mktemp -d "${TMPDIR:-/tmp}/xdrip-garmin-tests.XXXXXX")"
trap 'rm -rf "$build"' EXIT
swiftc -swift-version 5 -warnings-as-errors \
  "$root/xDrip/Managers/Garmin/GarminModels.swift" \
  "$root/xDrip/Managers/Garmin/GarminTransport.swift" \
  "$root/xDrip/Managers/Garmin/ConnectIQTransport.swift" \
  "$root/xDrip/Managers/Garmin/GarminManager.swift" \
  "$root/tests/garmin-delivery/AppDependencies.swift" \
  "$root/tests/garmin-delivery/main.swift" -o "$build/garmin-tests"
"$build/garmin-tests"
