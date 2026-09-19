# Direct Libre validation

Current implementation and setup: [Direct Libre guide](DirectLibre.md).
Baseline: upstream `develop` at `83009198dc5091398333f83aa832bbe3d99e3441`.
Historical milestone notes and superseded experiments remain in Git history; this
file records current evidence and pending acceptance only.

## Established checkpoints

| Area | Evidence | Limit |
| --- | --- | --- |
| Phone NFC/protocol extraction | Ordinary NFC, fresh readings, cancellation and signal-loss recovery passed on device; later recovery under 30 seconds | Earlier prototype-upgrade disconnect required reinstall; cause not conclusively established |
| Shared protocol | Upstream unlock/decryption fixtures and 176 captured frame comparisons matched calibrated/raw parsing | Does not establish other Libre variant support |
| Switching | Both directions passed with confirmed local disconnect, without Bluetooth cycling; restart, double-tap and NFC reset passed | Controlled interruption remains untested because transfer completed too quickly |
| Readings, milestone 6 (`8f0b3897`) | User passed live sync, configured downstream services, offline history recovery, units/limits/cache, trend/antenna and return to phone | No fixed background-delivery deadline established |
| Runtime (`2e6ff63f`) | 60 core tests; 11 location, 5 notification and 6 coordinator/antenna test groups passed; targeted SDK checks passed | Foreground/background/water/battery behaviour awaits devices |

## Consolidation checks

The cleanup removes obsolete non-NFC compilation fallback from the phone-only
adapter, an unused reset argument/result, preparation-ID reuse no longer reachable
through the UI, duplicate latest-reading work and deprecated Watch lifecycle naming.
Runtime payloads and history notification types/tests are grouped with related code.
No protocol phase, wire key, saved field, reading-retention rule or counter safeguard
is removed. NFC session method bodies remain unchanged.

Run the committed `GlucoseTrendTests`, `Libre2ProtocolTests`, `Libre2CollectorTests`,
`Libre2ConnectionTests`, `Libre2HistoryTests` (including the current-reading tests in
that file), and hosted `Libre2PhoneHistorySyncTests` through the `xdrip` test scheme.
Hosted Core Data tests require the app test host; portable tests do not prove iOS
persistence, UI rendering or Watch scheduling.

Cleanup verification passed: all 60 portable core tests, 27 Watch / 8 phone delivery
scenarios, 96 ordinary-phone processing combinations, 5 phone-control and 6 Watch
coordinator/antenna groups. Real iOS SDK checks passed for the changed phone code
and hosted test sources; the Watch dependency closure also type-checked. NFC method
bodies, shared BLE/authentication, wire payloads and runtime helpers were compared
with the prior commit and are unchanged. Both full scheme builds still encounter
the compiler-plugin blocker below. No hosted Core Data test execution is claimed.
Local harnesses and logs are in workspace `validation/integrated-cleanup`, outside
the checkout.

## Build environment

Xcode 27.0 (27A266a) here cannot run the SwiftUI compiler-plugin sandbox:
`sandbox_apply: Operation not permitted` and malformed `SwiftUIMacros.StateMacro` /
preview plugin responses. Unchanged baseline and current unsigned phone/Watch
scheme builds encounter this blocker in existing extension/chart sources. CoreSimulator
services are also unavailable in this execution environment. Successful targeted
SDK type-checks are not complete builds. UI checks using temporary State-wrapper
substitutes establish types only, not macro expansion or rendering.

Use normal Xcode device builds for acceptance. Keep personal signing/scheme changes
out of feature commits. For command-line compile checks, use explicit output paths
because upstream empty OBJROOT/SYMROOT settings can produce root/repository artifacts:

```sh
xcodebuild -project xdrip.xcodeproj -scheme xdrip -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/direct-libre-phone \
  OBJROOT=/tmp/direct-libre-phone/Intermediates SYMROOT=/tmp/direct-libre-phone/Products \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

xcodebuild -project xdrip.xcodeproj -scheme 'xDrip Watch App' -configuration Debug \
  -destination 'generic/platform=watchOS' -derivedDataPath /tmp/direct-libre-watch \
  OBJROOT=/tmp/direct-libre-watch/Intermediates SYMROOT=/tmp/direct-libre-watch/Products \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## Next device regression checklist

Install over the existing integrated build after returning collection to phone;
retain logs if a failure occurs before resetting or reinstalling.

1. With optional location off, ordinary phone NFC, fresh readings, cancellation,
   short/long signal loss and automatic recovery retain their original behaviour.
2. Switch both ways; verify actual readings and phone suspension. Restart during
   collection, double-tap, cycle Watch Bluetooth and retry an interrupted transfer.
   A failed/cancelled transfer must not silently enable both collectors.
3. While Watch is selected, successfully scan on phone with Watch unreachable;
   verify phone reclaim and Watch revocation once it receives the reset.
4. Check live readings and configured downstream actions, then collect offline,
   reconnect and verify latest delivery independent of backlog, durable history,
   no duplicates and no replay of old readings as current alarms.
5. Restart Watch without phone: units, limits and recent values persist. Confirm
   arrow/antenna states and that old phone readings do not replace newer values.
6. Enable location, grant permission and refresh runtime status. Background both
   apps and compare real measurement timestamps. Try all accuracy options, disable,
   return/reset and relaunch. Accuracy changes must not restart BLE; returning/reset
   must stop location once received. Repeat with denied/restored permission.
7. Schedule the test notification, return to Watch face and lock phone. Verify the
   alert appears on Watch; compare subsequent timestamps without opening either app.
8. With manual Water Lock, test foreground behaviour with location off/on and radio
   recovery after water exposure. Record when reliable sensor range resumes.

The integrated UI remains experimental. Extended diagnostic capture, measured
connection latency and battery comparisons are separate remaining work, not implied
by passing these host tests.
