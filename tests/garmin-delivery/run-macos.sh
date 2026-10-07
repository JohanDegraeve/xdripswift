#!/usr/bin/env bash
# Local verification only. Does not sign, install, archive or upload the app.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
    printf '%s\n' 'This check requires macOS with Xcode selected by xcode-select.' >&2
    exit 1
fi
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
xcodebuild -version
bash tests/garmin-delivery/run.sh
build="$(mktemp -d "${TMPDIR:-/tmp}/xdrip-garmin-xcode.XXXXXX")"
printf 'Build logs and DerivedData: %s\n' "$build"
xcodebuild -resolvePackageDependencies -project xdrip.xcodeproj -scheme xdrip \
    -clonedSourcePackagesDirPath "$build/packages" 2>&1 | tee "$build/resolve.log"
xcodebuild -project xdrip.xcodeproj -scheme xdrip -configuration Debug \
    -destination 'generic/platform=iOS' -derivedDataPath "$build/DerivedData" \
    -clonedSourcePackagesDirPath "$build/packages" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build 2>&1 | tee "$build/build.log"
# Select an installed simulator explicitly, e.g. platform=iOS Simulator,id=<UUID>.
# Omitted by default because installed simulator names/OS versions vary.
if [[ -n "${GARMIN_TEST_DESTINATION:-}" ]]; then
    xcodebuild -project xdrip.xcodeproj -scheme xdrip -configuration Debug \
        -destination "$GARMIN_TEST_DESTINATION" -derivedDataPath "$build/DerivedData" \
        -clonedSourcePackagesDirPath "$build/packages" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test 2>&1 | tee "$build/tests.log"
fi
