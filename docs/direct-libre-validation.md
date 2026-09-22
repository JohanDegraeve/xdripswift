# Direct Libre validation

Implementation and setup: [Direct Libre guide](direct-libre.md).
Review order and file counts: [maintainer review guide](direct-libre-maintainer-review.md).
Upstream: `develop` at `c268542e` (7.1.1, build 4233).
This file records current evidence and remaining device acceptance. Earlier milestone
reports and test totals remain in Git history.

The September 22 merge preserves the shared Bluetooth/Libre implementation, Watch
collector and handoff/history code unchanged. The sole merge conflict combined test
entries in the Xcode project; upstream's battery-history model v32 is retained.

## Automated checks

- 101 portable tests cover session/counter persistence, ownership transitions, parsing,
  frame assembly, trends, signal strength, history and bounded diagnostic capture.
- A differential test compares 176 synthetic calibrated/raw frames with the exact
  upstream parser, including timestamps, sensor age and saved overlap history.
- Seven shared-collector callback cases use platform doubles to check subscription/
  unlock order, save failure, suppression, discovery failure, ownership guards,
  captured arrival time and release before queued delivery.
- Transport checks cover 27 Watch delivery and eight phone import scenarios. Another
  96 combinations compare ordinary phone downstream processing with current upstream,
  including accepted-reading logging after processing and fresh/history distinctions.
- Five phone-control, six Watch coordinator/antenna, 11 location and five notification
  groups cover switching, reset, stale callbacks and optional runtime controls.

These host tests do not establish CoreBluetooth radio behavior, Watch scheduling or
hosted iOS Core Data persistence. `Libre2PhoneHistorySyncTests` requires the app test
host. Run the committed tests through the normal `xdrip` test scheme when available.

The file consolidation retains method bodies, wire formats and persistence rules.
Phone-only array and FRAM helpers are excluded from Watch compilation with `#if os(iOS)`.
NFC methods live in the iPhone-only transmitter again. Shared BLE remains in its
existing phone/Watch target memberships. Device identity now relies on upstream's
common connection bookkeeping; there is no second Watch save.

Current local harnesses and logs are in workspace `validation/integrated-footprint`;
upstream-comparison evidence is in `validation/integrated-upstream-merge`. Targeted
phone and Watch SDK checks cover the shared source dependency closures. Full builds
remain subject to the environment limitation below.

## Build environment

Xcode 27.0 (27A266a) in the automated environment cannot run the SwiftUI preview
compiler-plugin sandbox. Phone/Watch scheme builds stop in extension targets with
`swift-plugin-server` / external macro implementation errors. Targeted type-checks
are not full application builds, rendered UI tests or physical-device validation.
Build and cache outputs belong outside the checkout:

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

## Device acceptance

Earlier device checkpoints passed ordinary NFC/fresh readings, cancellation and
signal-loss recovery, both transfer directions, reset/restart, synchronisation,
configured downstream services and display persistence. Background collection has
worked in testing; long-term reliability and battery impact remain unmeasured.
Those checkpoints precede the current upstream merge and need reconfirmation.

Install matching phone/Watch builds over the existing integrated installation after
returning collection to phone. Retain logs before resetting if something fails.

1. With location off, check ordinary phone NFC, fresh readings, cancellation and
   automatic recovery after short and long signal loss.
2. Transfer both ways with confirmed release; restart, double-tap and cycle Watch
   Bluetooth. Retry an interrupted transfer without silently enabling both collectors.
3. Scan successfully on phone while Watch is unreachable; verify phone reclaim and
   Watch revocation after it receives the reset.
4. Check live imports and configured downstream actions. Collect offline, reconnect
   and confirm latest delivery independent of backlog, durable history, no duplicates
   and no replay of old readings as current alerts.
5. Restart Watch without phone: confirm units, limits and direct readings restore,
   arrows/antenna are correct, and older phone readings cannot replace newer data.
6. Enable location and background both apps. Compare measurement timestamps, test all
   accuracy options, disable, return/reset and relaunch. Repeat with permission denied
   and restored. Accuracy changes must not restart BLE.
7. Schedule the test notification, return to Watch face and lock phone. Confirm the
   alert reaches Watch and compare subsequent delivery without opening either app.
8. With manual Water Lock, test foreground and recovery behavior with location off/on.
   Record when reliable sensor range resumes; do not infer system throttling from
   a pending connection or silent interval alone.

Before a pool visit, run a dry diagnostic capture: start connected, double-tap, cycle
Watch Bluetooth, separate the phone, relaunch Watch, then stop/download/share. Confirm
that the report retains its beginning, identifies separate app runs and ends explicitly.
Compare collection with capture off/on. Earlier pool observations included grey reset
indicators and recovery needing Bluetooth cycling; their cause remains unresolved.
