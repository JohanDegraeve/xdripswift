# Direct Libre validation

Current implementation and setup: [Direct Libre guide](DirectLibre.md).
Current upstream: `develop` at `0370937605a59f520f2d4eb6bec79fcc3cc3af88`.
Earlier device checkpoints below precede this upstream merge and need reconfirmation.
Historical milestone notes and superseded experiments remain in Git history; this
file records current evidence and pending acceptance only.

## September 20 upstream merge

The merge adopts upstream's queued subscription/immediate unlock sequencing, frame
assembler, Bluetooth queue cleanup, signal-strength diagnostics and minimum trend
interval. Phone and Watch retain the same shared protocol; Watch counter persistence
and transfer/release guards remain in place. Ordinary NFC method bodies are unchanged
from the previous feature commit (upstream only edited a comment in the NFC utility).

Validation passed:

- 101 portable core, frame-assembly, trend, signal-strength and capture tests.
- 176 synthetic frame comparisons against the exact upstream parser, checking
  calibrated/raw values, timestamps, sensor age and persisted overlap history.
- Seven shared-collector callback cases with platform doubles: subscription/unlock
  ordering, persistence failure, suppression, discovery failure, ownership guards,
  captured arrival timestamps and release before delivery.
- 27 Watch / 8 phone delivery scenarios and 96 phone downstream combinations against
  current upstream, including accepted-reading activity logging after processing.
- Five phone-control, six Watch coordinator/antenna, 11 location and five notification
  groups.
- Watch dependency-closure and targeted iOS SDK type-checks, including shared BLE,
  parser adapters, trends, reading processing and hosted history test sources.

One capture stress test exceeded its ten-second timeout during concurrent full
builds. The unchanged test passed on rerun without competing compilers, and the
final 101-test run passed. Both full builds still stop at the SwiftUI preview-plugin
sandbox failure described below; no full build or hosted Core Data execution is
claimed. Logs and local harnesses: workspace `validation/integrated-upstream-merge`.

Device acceptance for this merge: ordinary phone NFC/fresh readings and signal-loss
recovery; phone → Watch → phone with confirmed release; Watch signal-loss/double-tap
recovery; trend arrows and live/history imports with configured downstream services.
Recheck optional location/background collection and diagnostic export with matching
phone and Watch builds.

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

The integrated UI remains experimental. Physical-device diagnostic capture acceptance, measured
connection latency and battery comparisons are separate remaining work, not implied
by passing these host tests.

## Watch diagnostic capture (September 20)

The pool test showed automatic foreground recovery after short submersion, some
longer losses requiring double-tap, and some requiring Watch Bluetooth cycling plus
double-tap. Resets sometimes showed a grey antenna. These observations motivate the
capture; they do not identify a system limit or demonstrate a fix.

`Libre2DiagnosticCaptureTests` is included in the existing `xdrip` test target.
Its 15 storage/recorder tests passed in a standalone host run: 90-minute retention,
relaunch/chunked export, stale/idempotent commands, capacity/expiry, corruption and
write failures, concurrent admission, disabled logging and event-origin timestamps.
The existing 60 core tests and six coordinator/antenna regression groups also passed;
the latter exercise the actual coordinator with simulated dependencies, including
reset/release ordering, late callbacks, grey on Bluetooth-off and power-on scanning.

Before a pool visit, install matching builds and perform a dry capture: start while
already connected, double-tap, cycle Watch Bluetooth, briefly separate the phone,
relaunch the Watch app, then stop/download/share. Check that the report retains its
beginning, distinguishes app runs and ends explicitly; compare normal collection
with capture off/on. Full device persistence, radio recovery and UI acceptance
remain physical-device checks. Logs and SDK/build check details are in workspace
`validation/integrated-capture/`.

Combined current host verification passed all **75 core/capture tests**, six
coordinator/antenna groups and 11 location groups with diagnostics enabled in the
location test double. Current Watch dependency closure and changed phone sources
passed real SDK type-checks. The new phone capture view passed a limited SDK check
with a temporary State-property substitute and a reachability model double; this
checks view types, not macro expansion or rendering. Both full scheme builds remain
blocked by the existing SwiftUI compiler-plugin sandbox failure described above.
Personal build configurations, plist and scheme edits were preserved.
